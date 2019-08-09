#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------

# Globals
_version="0.5"
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
        #evaluate "cd flyway_data/$folder"; evaluate "git pull" "SILENT"; evaluate "cd ../.." "SILENT";
        msg "flyway_data/$folder exists, skipping clone"
    else
        evaluate "cd flyway_data"
        evaluate "$source";
        evaluate "cd $_here"
    fi;
}

docker_compose_template() {
    cat <<EOF    
version: '3'
services:
  migrate-${folder}:
    container_name: "compose-flyway-${folder}"
    image: "boxfuse/flyway:latest"
    command: -url=jdbc:postgresql://postgresql:5432/${_database} -schemas=${flywaySchemaConf} -table=${folder}_versions -baselineOnMigrate=true -baselineVersion=0 -locations=filesystem:/flyway/sql/${folder} -user=postgres -password=postgres -connectRetries=60  migrate
    volumes:
      - ./flyway_data/${flywayLocationConf}:/flyway/sql/${folder}
    depends_on:
      - postgresql
EOF
}



function processConfig(){
 conf="$1"
 IFS=$'\n'  # make newlines the only separator

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
             flywayLocationConf=$( echo "$line" |cut -d'=' -f2 );
             read line   
             flywaySchemaConf=$( echo "$line" |cut -d'=' -f2 );
              
             OLDIFS="${IFS}"
             IFS=
             docker_compose_template > $folder.yml
             IFS="${OLDIFS}"   
             msg "$folder docker-compose created ..."          
           fi            
       fi;
    fi;   
 
 done < $conf
 #done
 
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
   
    processConfig $_configFile
    
    if [ "$_cleanup" == "1" ]; then cleanUp; fi; 
    msg ""
    msg "Done!"
    exit 0; 
fi;

echo "Try ss-tool --help for help";
echo "";
#FINISH
