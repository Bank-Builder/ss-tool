#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------

# Globals
_version="0.4"
_silent="0"
_configFile="ss-tool.conf"
_cleanup="0"
_here=$(pwd)
_db="db"
_db_docker="postgres:10"
_flyway_docker="boxfuse/flyway"
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


function flyway_config(){
 evaluate "cd $_here"
 if [ -d "$_here" ]; then evaluate "rm -rf flyway"; fi;
 evaluate "mkdir flyway"
 evaluate "cd flyway"
 evaluate "echo '## flyway configuration ##' > flyway.conf"
 evaluate 'echo "flyway.driver=org.postgresql.Driver" >> flyway.conf'
 evaluate 'echo "flyway.url=jdbc:postgresql://$_db_ip:5432/'${_database}'" >> flyway.conf'
 evaluate 'echo "flyway.user=postgres" >> flyway.conf'
 evaluate 'echo "flyway.password=postgres" >> flyway.conf'
 evaluate 'echo "flyway.cleanOnValidationError=false" >> flyway.conf'
 #evaluate 'echo "flyway.outoforder=true" >> flyway.conf' 
 evaluate 'echo "flyway.sqlMigrationPrefix=V" >> flyway.conf'
 evaluate 'echo "flyway.sqlMigrationSeparator=__" >> flyway.conf'
 evaluate 'echo "flyway.sqlMigrationSuffix=.sql" >> flyway.conf'
 evaluate 'echo "flyway.validateOnMigrate=true" >> flyway.conf'
 msg "Flyway configuration ..."
 evaluate "cd $_here"
}


function clearup_docker(){
 _name=$1
 msg "... clearing up $_name container"
 evaluate "docker stop $_name" "SILENT" 
 sleep 1
 evaluate "docker rm $_name" "SILENT" 
 sleep 1
}

function plan_migration(){
  if [ "$_fw_path" == "" ]; then 
    _fw_path=$1; 
  else 
    _fw_path="$_fw_path,$1"
  fi

  if [ "$_fw_schema" == "" ]; then 
    _fw_schema="public"; 
  else 
    _fw_schema="$_fw_schema,$2"
  fi
}

function migrate(){
 clearup_docker "fw"
 msg "FLYWAY_SCHEMAS=$_fw_schema FLYWAY_LOCATIONS=$_fw_path docker run --name fw --rm -v $_here/$fw_path:/flyway/sql -v $_here/flyway:/flyway/conf $_flyway_docker migrate"
}


function cleanUp(){
 msg "cleanup:"
 msg "----------"
 msg "iterating through and removing cloned repo sub-directories"
 
 evaluate "cd $_here"  
 #dir="git"
 #if [[ "~/." == *"$dir"* ]]; then printf "Dangerous config! \n[$dir] is not allowed\n"; exit; fi;
 evaluate "rm -rf git";
 msg "... deleted git";
 evaluate "rm -rf flyway";
 msg "... deleted flyway";
 clearup_docker "db"
 clearup_docker "fw"
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
 if [ ! -d "git/" ]; then
     evaluate "mkdir git"
 fi;

 if [ -d "git/$folder" ]; then
   #evaluate "cd git/$folder"; evaluate "git pull" "SILENT"; evaluate "cd ../.." "SILENT";
   msg "git/$folder exists, skipping clone"
 else
   evaluate "cd git"
   evaluate "$source";
   evaluate "cd $_here"
 fi;
}


function processConfig(){
 conf="$1"
 IFS=$'\n'

 for line in $(cat $conf)
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
           if [ "$header" == "canonical" ]; then
             _database=$schema
             msg "creating database $_database in docker db"
             
             sql='PGPASSWORD=postgres psql -U postgres -h localhost -p 9432 -t -c "CREATE DATABASE $_database ENCODING = "\""UTF8"\"" TABLESPACE = pg_default OWNER = postgres;"'; evaluate $sql
           fi
           msg " "
      else # label=value
          
           if [ "$confLabel" == "source" ] && [ "$confValue" != "" ]; then
             folder=$(git_folder "$confValue")
             echo "---$folder---"
             if [ "$header" == "canonical" ]; then _canonical_folder="$folder"; fi;
             echo $(clone "$confValue")
             msg "$folder cloned ..."
           fi
                      
           if [ "$header" == "canonical" ] && [ "$confLabel" == "flyway" ]; then
             _canonical_flyway=$confValue
             plan_migration "$confValue"
           fi
                      
           if [ "$header" == "microservice" ] && [ "$confLabel" == "flyway" ]; then
             plan_migration "$confValue" "_$schema"
           fi

           if [ "$header" == "canonical" ] && [ "$confLabel" == "sql" ]; then _canonical_sql="$confValue"; fi;

       fi;
    fi;   
  
 done
 
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

    clearup_docker "db"
    evaluate "docker pull $_db_docker" "SILENT"
    evaluate "docker run -d -p 9432:5432 --name db -e POSTGRES_PASSWORD=postgres $_db_docker" "SILENT"
    
    sleep 5 # wait for psql process inside the docker db to get going before trying to connect
    _db_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db)
    flyway_config
    processConfig $_configFile
    migrate

    if [ $_push_git == "1" ]; then # create branch & switch to it
       evaluate "cd $_here/git/$_canonical_folder"
       evaluate "git checkout -b $_git_ref-ss_tool-db-auto-update"; 
    fi
    
    evaluate "cd $_here/$_canonical_flyway"
    evaluate "PGPASSWORD=postgres pg_dump --file=$_canonical_sql -h localhost -p 9432 -d canonical --schema-only -U postgres"

    if [ $_push_git == "1" ]; then # git add , git commit, git push upstream
      evaluate "cd $_here/git/$_canonical_folder"  
      evaluate "git add db/$_canonical_sql"
      evaluate "git commit -m $_git_ref-ss_tool-db-auto-update"
      evaluate "git push --set-upstream origin $_git_ref-ss_tool-db-auto-update"
    fi; 
    #evaluate "git checkout master"
    evaluate "cd $_here"
    
    if [ "$_cleanup" == "1" ]; then cleanUp; fi; 
    msg "Done!"
    exit 0; 
fi;

echo "Try ss-tool --help for help";
echo "";
#FINIS
