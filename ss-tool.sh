#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------

# Globals
_version="0.6"
_silent="0"
_configFile="ss-tool.conf"
_cleanup="0"
_here=$(pwd)
_db="db"
_database="canonical"
_git_ref="$(date +%Y%m%d-%H%M)"
_push_git="0"
_fw_path=""
_fw_schema=""


function displayHelp(){
    echo "Usage: ss-tool [OPTION]...";
    echo "   Clones the repositories of multiple microservices as per the ss.conf file";
    echo "   and drops & recreates these discrete schemas into a single canonical database";
    echo "   which it then round-trips back into the canonical repository";
    echo " ";
    echo "  OPTIONS:";
    echo "    -f, --file      supply optional file name of alternative ss-tool.conf file";
    echo "    -s, --silent    does not display verbose details";
    echo "    -c, --cleanup   removes all git cloned sub-directories & docker db when done";
    echo "    -g, --git-ref   add an optional custom git reference eg 243 to match issue 243";
    echo "    -p, --push-git  push to GitHub, default behaviour creates branch but does not push";
    echo "        --help      display this help and exit";
    echo "        --version   display version and exit";
    echo "";
    echo "";
    echo "  EXAMPLE(s):";
    echo "      ss-tool --cleanup -g 243";
    echo "           will remove all git cloned repositories & docker db when done";
    echo "           and add a git-ref of '243-ss_tool-db-auto-update' when pushing the changes";
    echo "";
    echo "      ss-tool.conf:";
    echo "          [canonical-database] section";
    echo "          [<microservice>] section(s) giving details of repo with amongst other settings, ";
    echo "                           the source path to the Flyway SQL scripts for";
    echo "                           the micro-service schemas";
    echo "";
}


function displayVersion(){
    echo "ss-tool (bank-builder utils) version $_version";
    echo "Copyright (C) 2019, Andrew Turpin";
    echo "License MIT: https://opensource.org/licenses/MIT";
    echo "";
}


function trim(){
    echo $1 | xargs
}


function msg(){
    if [ "$_silent" != "1" ]; then echo "$1"; fi
}


function evaluate(){
    # executes by eval but without outputting to screen and returns exit code
    if [ "$_silent" == "1" ] || [ "$2" == "SILENT" ]; then
      eval "$1" > /dev/null 2>&1
    else # don't redirect stdout to null & error to stdout
      eval "$1" 
    fi
    return $?
}

function cleanUp(){
    msg "cleanup:"
    msg "----------"
    msg "iterating through and removing cloned repo sub-directories"
 
    evaluate "cd $_here"  
    evaluate "docker-compose down -v";
    evaluate "rm -rf flyway_data";    
    msg "... deleted flyway_data";
    msg "----------"
}

function git_folder(){
    #takes git clone string as parameter
    ff=$( echo "$1" |cut -d'/' -f2 );
    ff=$( echo "$ff" |cut -d'.' -f1 );
    echo "$ff"; #function returns the git folder name
}

function clone(){
    source=$1 
    folder=$(git_folder "$source"); 
    evaluate "cd $_here"
    if [ ! -d "flyway_data/" ]; then
        evaluate "mkdir flyway_data"
    fi;

    if [ -d "flyway_data/$folder" ]; then
        msg "flyway_data/$folder exists, skipping clone"
    else
        evaluate "cd flyway_data"
        evaluate "$source";
        evaluate "cd $_here"
    fi;
}

docker_compose_header() {
    cat <<EOF    
version: '3'
services:
EOF
}

docker_compose_template() {
    cat <<EOF    
  migrate-${folder}:
    container_name: "compose-flyway-${folder}"
    image: "boxfuse/flyway:latest"
    command: -url=jdbc:postgresql://postgresql:5432/${_database} -schemas=${flywaySchema} -table=${folder}_versions -baselineOnMigrate=true -baselineVersion=0 -locations=filesystem:/flyway/sql/${folder} -user=postgres -password=postgres -connectRetries=60  migrate
    volumes:
      - ./flyway_data/${flywayLocationConf}:/flyway/sql/${folder}
      - ./postgres.conf:/flyway/conf/postgres.conf
      - ./wait-for.sh:/wait-for.sh
    depends_on:
      - postgresql
EOF
}

docker_compose_canonical_template() {
    cat <<EOF    
  migrate-${folder}:
    container_name: "compose-flyway-${folder}"
    image: "boxfuse/flyway:latest"
    command: -url=jdbc:postgresql://postgresql:5432/${_database} -table=${folder}_versions -baselineOnMigrate=true -baselineVersion=0 -locations=filesystem:/flyway/sql/${folder} -user=postgres -password=postgres -connectRetries=60  migrate
    volumes:
      - ./flyway_data/${flywayLocationConf}:/flyway/sql/${folder}
      - ./postgres.conf:/flyway/conf/postgres.conf
      - ./wait-for.sh:/wait-for.sh
    depends_on:
      - postgresql
EOF
}

docker_compose_footer() {
    cat<<EOF
  postgresql:
    image: "postgres:10.7-alpine"
    restart: always
    command: "-c 'config_file=/etc/postgresql/postgresql.conf'"
    ports:
      - "9432:5432"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_DB=canonical
    volumes: 
      - ./postgres.conf:/etc/postgresql/postgresql.conf
EOF
}

docker_run_template() {
    cat <<EOF 
#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------   
docker run --rm -v ${_here}/git/${flywayLocationConf}:/flyway/sql/${folder} -v ${_here}/flyway:/flyway/config boxfuse/flyway:latest -url=jdbc:postgresql://172.24.0.2:9432/${_database} -configFiles=config/flyway.conf -schemas=${flywaySchema} -table=${folder}_versions -baselineOnMigrate=true -baselineVersion=0 -locations=filesystem:/flyway/sql/${folder} -user=postgres -password=postgres -connectRetries=10  migrate
EOF
}
docker_run_template_no_schema() {
    cat <<EOF 
#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------   
docker run --rm -v ${_here}/git/${flywayLocationConf}:/flyway/sql/${folder} -v ${_here}/flyway:/flyway/config boxfuse/flyway:latest -url=jdbc:postgresql://postgresql:9432/${_database} -configFiles=config/flyway.conf -table=${folder}_versions -baselineOnMigrate=true -baselineVersion=0 -locations=filesystem:/flyway/sql/${folder} -user=postgres -password=postgres -connectRetries=10  migrate
EOF
}

function processConfig(){
 conf="$1"
 IFS=$'\n'  # make newlines the only separator

 OLDIFS="${IFS}"
 IFS=
 docker_compose_header > flyway_data/canonical.yml
 IFS="${OLDIFS}"
 

 #for line in $(cat $conf)
 while read line 
 do
   line=$(trim $line)
   confLabel=$( echo "$line" |cut -d'=' -f1 );
   confValue=$( echo "$line" |cut -d'=' -f2 ); 
   if [[ ${confLabel:0:1} != "#" ]] ; then #not a comment nor a blank line

       tmp=${confLabel#*[}   # remove prefix ending in "["
       section=${tmp%]*}     # remove suffix starting with "]"

       if [ "$confLabel" == "[$section]" ]; then # [section] header
           
           header=$( echo "$section" |cut -d':' -f1 );
           schema=$( echo "$section" |cut -d':' -f2 );
           msg " "
      else # label=value
          
           if [ "$confLabel" == "source" ] && [ "$confValue" != "" ]; then
             folder=$(git_folder "$confValue")
             echo "---$folder---"
             if [ "$header" == "canonical" ]; then _canonical_folder="$folder"; fi;
             echo $(clone "$confValue")  #clones the git repo from source tag in conf file
             msg "$folder cloned ..."
             
             read line   
             key=$( echo "$line" |cut -d'=' -f1 );             
             value=$( echo "$line" |cut -d'=' -f2 );
             if [ "$header" == "canonical" ] && [ "$key" == "sql" ]; then
                _canonical_sql="$value";
             fi;
             if [ "$key" == "flyway" ]; then
                flywayLocationConf="$value";
             else # schema
                flywaySchema="$value";
             fi;
             read line   
             key=$( echo "$line" |cut -d'=' -f1 );             
             value=$( echo "$line" |cut -d'=' -f2 );
             if [ "$header" == "canonical" ] && [ "$key" == "sql" ]; then
                _canonical_sql="$value";
             fi;
             if [ "$key" == "flyway" ]; then
                flywayLocationConf="$value";
             else # schema
                flywaySchema="$value";
             fi;
             
             _docker_run_overides="$_docker_run_overides ./flyway_data/$folder.sh ||"; 
            _microservices_list="$_microservices_list$folder "
             
             if [ "$header" == "canonical" ]; then
                OLDIFS="${IFS}"
                IFS=
                docker_compose_canonical_template >> flyway_data/canonical.yml
                IFS="${OLDIFS}"
                msg "$folder docker-compose created ..."
             else
                OLDIFS="${IFS}"
                IFS=
                docker_compose_template >> flyway_data/canonical.yml
                IFS="${OLDIFS}"
                msg "$folder docker-compose created ..."
            fi;
           fi  			
       fi;
    fi;
 done < $conf
 #done
 docker_compose_footer >> flyway_data/canonical.yml
 # evaluate "cat flyway_data/canonical.yml"
}

# __Main__
while [[ "$#" > 0 ]]; do
    case $1 in
        --help) 
            displayHelp; exit 0;;
        --version) 
            displayVersion; exit 0;;
        -f|--file) 
            _configFile="$2";
            shift;;
        -s|--silent) 
            _silent="1"
            ;;
        -c|--cleanup) 
            _cleanup="1";
            ;;
        -p|--push-git) 
            _push_git="1";
            ;;            
        -g|--git-ref) 
            _git_ref="$2";
            shift;;
         *) echo "Unknown parameter passed: $1"; exit 1;;
    esac; 
    shift; 
done

if [ -n "$_configFile" ]; then
    if [ "$_silent" == "0" ]; then 
        msg "ss-tool ver $_version"
        msg "======================";
    fi

    msg "======================";
    msg "pulling docker images"
    evaluate "docker pull postgres:10.7-alpine"
    evaluate "docker pull boxfuse/flyway:latest"
    msg "======================";

    msg "======================";
    msg "copy connection config to temp folder"
    evaluate "cp -r flyway flyway_data/flyway"
    evaluate "cp postgres.conf flyway_data/postgres.conf"
    evaluate "cp wait-for.sh flyway_data/wait-for.sh"
    msg "======================";

    processConfig $_configFile
     
    msg "======================";
    msg "" 
    msg "Starting postgres & flyway migrations for each microservice ... " 
    _docker_compose_cmd="docker-compose -f $_here/flyway_data/canonical.yml up -d" # -f docker-compose.yml -f public.yml 
    msg "$_docker_compose_cmd"
    evaluate "$_docker_compose_cmd"

    # evaluate "docker inspect -f '{{ range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' flywaydata_postgresql_1"
     
    msg "Sleeping for 10!" 
    sleep 10 # wait for psql processes inside the docker containers to run etc. before trying to connect
    msg "Done Sleeping!"
    msg "======================";
    msg ""

    OLDIFS="${IFS}"
    IFS=' '
    for i in $(echo $_microservices_list | sed "s/,/ /g")
    do
	    error_count=$(docker logs compose-flyway-$i 2>&1 | grep "ERROR" | wc -l)
	    if [ "$error_count" -gt 0 ]; then
	        msg ""
	     	msg "FAILED:: $error_count errors in $i flyway logs";
	     	msg "  View these by running 'docker logs compose-flyway-$i '"
	     	
	     	#TODO: below is a temp message whilst we iron out where schema creationg and public setup is
	     	msg ""
		    msg "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#" 
		    msg "NOTE:: if this is the first time you running the ss-tool with dokuti and tilkynna to correct this failure comment out these lines in the following files::"
		    msg " - line 21: CREATE SCHEMA _documents;     in file flyway_data/dokuti/src/main/resources/db/migration/V1__init.sql"
		    msg " - line 29: CREATE EXTENSION IF NOT EXISTS pgcrypto;      in file flyway_data/tilkynna/src/main/resources/db/migration/postgresql/V1__init.sql"
		    msg "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
		    
	     	exit 0; 
	    fi	     
	done
    IFS="${OLDIFS}"

    msg "======================";
    msg "mkdir -p $_here/flyway_data/$_canonical_folder/"
    evaluate "mkdir -p $_here/flyway_data/$_canonical_folder/"
    # msg "docker exec -u postgres flywaydata_postgresql_1 pg_dump -h postgresql -p 9432 -d canonical --schema-only  > $_here/flyway_data/$_canonical_folder/$_canonical_sql"
    # evaluate "docker exec -u postgres flywaydata_postgresql_1 pg_dump -h postgresql -p 9432 -d canonical --schema-only  > $_here/flyway_data/$_canonical_folder/$_canonical_sql"
    msg "docker exec -u postgres flywaydata_postgresql_1 pg_dump -d canonical --schema-only  > $_here/flyway_data/$_canonical_folder/$_canonical_sql"
    evaluate "docker exec -u postgres flywaydata_postgresql_1 pg_dump -d canonical --schema-only  > $_here/flyway_data/$_canonical_folder/$_canonical_sql"
    
    if [ $_push_git == "1" ]; then # git add , git commit, git push upstream
      evaluate "cd $_here/flyway_data/$_canonical_folder"  
      evaluate "git add $_canonical_sql"
      evaluate "git commit -m $_git_ref-ss_tool-db-auto-update"
      #evaluate "git push --set-upstream origin $_git_ref-ss_tool-db-auto-update"
      evaluate "git push"
    fi
    msg ""
    msg "cd $_here"
    evaluate "cd $_here"
        
    if [ "$_cleanup" == "1" ]; then cleanUp; fi; 
    msg ""
    msg "Done! SQL for Canonical DB is at: '$_here/flyway_data/$_canonical_folder/$_canonical_sql'"
    exit 0; 
fi;

echo "Try ss-tool --help for help";
echo "";
#FINISH
