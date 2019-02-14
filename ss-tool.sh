#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------

# Globals
_version="0.3"
_silent="0"
_configFile="ss-tool.conf"
_cleanup="0"
_here=$(pwd)

function displayHelp(){
 echo "Usage: ss-tool [OPTION]...";
 echo "   Clones the repositories of multiple microservices as per the ss.conf file";
 echo "   and drops & recreates these discrete schemas into a single canonical database";
 echo "   which it then round-trips back into the canonical repository";
 echo " ";
 echo "  OPTIONS:";
 echo "    -f, --file      supply optional file name of alternative ss-tool.conf file";
 echo "    -s, --silent    does not display vebose details";
 echo "    -c, --cleanup   removes all git cloned sub-directories & docker db when done";
 echo "        --help      display this help and exit";
 echo "        --version   display version and exit";
 echo "";
 echo "";
 echo "  EXAMPLE(s):";
 echo "      ss-tool --cleanup";
 echo "           will remove all git cloned repositories & docker db when done";
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
 if [ "$_silent" != "1" ]; then
    eval "$1"
 else # redirect stdout to null & error to stdout i.e. go silent
    eval "$1" > /dev/null 2>&1
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
 evaluate 'echo "flyway.url=jdbc:postgresql://localhost:8432/$database" >> flyway.conf'
 evaluate 'echo "flyway.user=postgres" >> flyway.conf'
 evaluate 'echo "flyway.password=postgres" >> flyway.conf'
 evaluate 'echo "flyway.locations=filesystem:src/main/resources/flyway/migrations" >> flyway.conf'
 evaluate 'echo "flyway.sqlMigrationPrefix=V" >> flyway.conf'
 evaluate 'echo "flyway.sqlMigrationSeparator=__" >> flyway.conf'
 evaluate 'echo "flyway.sqlMigrationSuffix=.sql" >> flyway.conf'
 evaluate 'echo "flyway.validateOnMigrate=true" >> flyway.conf'
 msg "Flyway configuration ..."
 evaluate "cd .."
}


function cleanUp(){
 msg "cleanup:"
 msg "----------"
 msg "iterating through and removing cloned repo sub-directories"
 
 evaluate "cd $_here"  
 dir="git"
 if [[ "~/." == *"$dir"* ]]; then printf "Dangerous config! \n[$dir] is not allowed\n"; exit; fi;
 evaluate "rm -rf $dir";
 msg "... deleted $dir";
 
 msg "... removing docker db"
 evaluate "docker stop db"; if [ "$?" != "0" ]; then msg "... error stopping db"; fi;
 evaluate "docker rm db"; if [ "$?" != "0" ]; then msg "... error removing db"; fi;
 
 msg "... removing docker fw"
 evaluate "docker stop fw"; if [ "$?" != "0" ]; then msg "... error stopping fw"; fi;
 evaluate "docker rm fw"; if [ "$?" != "0" ]; then msg "... error removing fw"; fi;
 msg "----------"
}

function clone(){
 source=$1  #git clone string
 folder=$( echo "$source" |cut -d'/' -f2 );
 folder=$( echo "$folder" |cut -d'.' -f1 );
 
 if [ ! -d "git/" ]; then
     evaluate "mkdir git"
 fi;
 
 if [ -d "git/$folder" ]; then
   msg "pulling $folder";
   evaluate "cd git/$folder"; evaluate "git pull"; evaluate "cd ../..";
 else
   msg "cloning $source"
   evaluate "cd git"
   evaluate $source;
   evaluate "cd .."
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
             msg "creating database $schema in docker db"
             sql='PGPASSWORD=postgres psql -U postgres -h localhost -p 8432 -t -c "CREATE DATABASE $schema ENCODING = "\""UTF8"\"" TABLESPACE = pg_default OWNER = postgres;"'; evaluate $sql
           fi;
           msg "..."
      else # label=value
           # clone repo's for canonical & all microservice sections
           if [ "$confLabel" = "source" ] && [ "$confValue" != "" ]; then msg $(clone $confValue); fi;
           
           
           
           if [ "$header" == "microservice" ] && [ "$confLabel" == "flyway" ]; then 
             msg "executing flyway scripts at $confValue for $schema"
             # execute flyway
           fi
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
            shift;
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1;;
    esac; 
    shift; 
done

if [ -n "$_configFile" ]; then
    if [ "$_silent" == "0" ]; then 
        msg "ss-tool ver $_version"
        msg "======================";
    fi
    
    # consider using a docker compose script to achieve this
    
    flyway_config
    
    msg "spinning up Flyway docker container ..."
    evaluate "docker pull boxfuse/flyway"
    evaluate "docker stop fw"
    evaluate "docker rm fw"
    evaluate "docker stop fw"
    evaluate "docker run --name fw --rm boxfuse/flyway"
    
    msg "spinning up postgress docker container ..."
    evaluate "docker pull postgres:latest"
    evaluate "docker stop db"
    evaluate "docker rm db"
    evaluate "docker run -d -p 8432:5432 --name db -e POSTGRES_PASSWORD=postgres postgres"
    
    sleep 5 # wait for psql process inside the docker db to get going before trying to connect
  
    processConfig $_configFile
    
    # update the canonical repo with revised sql
    # git   push -u
    # msg "canonical/ git push -u" 
    
    if [ "$_cleanup" == "1" ]; then cleanUp; fi; 
    msg "Done!"
    exit 0; 
fi;

echo "Try ss-tool --help for help";
echo "";
#FINIS
