#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2019, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
#-----------------------------------------------------------------------


_version="0.2"

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
 echo "                           the source path to the FlyWay SQL scripts for";
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

evaluate(){
 # executes by eval but without outputting to screen and returns exit code
 eval "$1" > /dev/null 2>&1
 return $?
}

function cleanUp(){
 echo "cleanup:"
 echo "----------"
 echo "iterating through and removing cloned repo sub-directories"
 IFS=$'\n';declare -a folders=("$(ls -d */)");
 for dir in ${folders[@]};
 do 
     # exit if dangerous folder names in config
     if [[ "~/." == *"$dir"* ]]; then 
         printf "Dangerous config! \n[$dir] is not allowed in .conf\n"; exit; 
     fi;
     #$(rm -rf $dir);
     echo "... deleted $dir";
 done
 echo "... removing docker db"
 evaluate "docker stop db"; if [ "$?" != "0" ]; then echo "... error stopping db"; fi;
 evaluate "docker rm db"; if [ "$?" != "0" ]; then echo "... error removing db"; fi;
 echo "----------"
}

function clone(){
 source=$1  #git clone string
 folder=$( echo "$source" |cut -d'/' -f2 );
 folder=$( echo "$folder" |cut -d'.' -f1 );

 if [ -d "$folder" ]; then
   echo -e "pulling $folder";
   evaluate "cd $folder"; evaluate "git pull"; evaluate "cd ..";
 else
   echo -e "cloning $source"
   eval $source;
 fi;
}

function processConfig(){
 Config="$1"
 Verbose="$2"
 
 IFS=$'\n'

 for line in $(cat $Config)
 do
   line=$(trim $line)
   confLabel=$( echo "$line" |cut -d'=' -f1 );
   confValue=$( echo "$line" |cut -d'=' -f2 ); 
   if [[ ${confLabel:0:1} != "#" ]] ; then #not a comment nor a blank line

       tmp=${confLabel#*[}   # remove prefix ending in "["
       section=${tmp%]*}   # remove suffix starting with "]"

       if [ "$confLabel" == "[$section]" ]; then # [section] header
           
           header=$( echo "$section" |cut -d':' -f1 );
           schema=$( echo "$section" |cut -d':' -f2 );
           if [ "$header" == "canonical" ]; then
             echo "creating database $schema in docker db"
             sql='PGPASSWORD=postgres psql -U postgres -h localhost -p 8432 -t -c "CREATE DATABASE $schema ENCODING = "\""UTF8"\"" TABLESPACE = pg_default OWNER = postgres;"'; evaluate $sql
           fi;
           echo "..."
      else # label=value
           #do this for both datbase & microservice sections
           if [ "$confLabel" = "source" ] && [ "$confValue" != "" ]; then echo $(clone $confValue); fi;
           
           
           
           if [ "$header" == "microservice" ] && [ "$confLabel" == "flyway" ]; then 
             echo "executing flyway scripts at $confValue for $schema"
           fi
       fi;
    fi;   
  
 done
 
}



# __Main__
_verbose="1"
_configFile="ss-tool.conf"
_cleanup="0"

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
            _verbose="0"
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
    if [ "$_verbose" = "1" ]; then 
        _title="ss-tool ver $_version";
        _title="$_title\n======================";
        echo -e $_title
    fi
    
    echo "spinning up postgress docker container ..."
    evaluate "docker pull postgres:latest"
    evaluate "docker stop db"
    evaluate "docker rm db"
    evaluate "docker run -d -p 8432:5432 --name db -e POSTGRES_PASSWORD=postgres postgres"
    sleep 5 # wait for psql process inside the docker db to get going before trying to connect
  
    processConfig $_configFile $_verbose 
    
    # update the canonical repo with revised sql
    # git   push -u
    # echo "canonical/ git push -u" 
    
    if [ "$_cleanup" == "1" ]; then cleanUp; fi; 
    echo "Done!"
    exit 0; 
fi;

echo "Try ss-tool --help for help";
echo "";
#FINIS
