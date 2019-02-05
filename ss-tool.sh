#!/bin/bash
# Copyright (c) 2018, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
# Schema Sync - known as ss, is a tool to sync the postgres schemas from 
#               multiple microservices into a single cannonical view
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
 echo "    -c, --cleanup   removes all git cloned sub-directories when done";
 echo "        --help      display this help and exit";
 echo "        --version   display version and exit";
 echo "";
 echo "";
 echo "  EXAMPLE(s):";
 echo "      ss-tool --cleanup";
 echo "           will remove all the sub-folders of cloned repositories after it has completed executing.";
 echo "";
 echo "      ss-tool.conf:";
 echo "          [canonical-database] section";
 echo "          [<microservice>] section(s) giving details of repo with amongst other settings, ";
 echo "                           the source path to the FlyWay SQL scripts to";
 echo "                           add micro-service schemas to canonical-database";
 echo "";
}

function displayVersion(){
 echo "ss-tool (bank-builder utils) version $_version";
 echo "Copyright (C) 2019, Andrew Turpin";
 echo "License MIT: https://opensource.org/licenses/MIT";
 echo "";
}

function evaluate(){
 #if _verbose="0" then redirect stdout to null else show on screen
 eval "$1"
}

function processConfig(){
 Config="$1"
 Verbose="$2"
 IFS=$'\n'

 for line in $(cat $Config)
 do
   confLabel=$( echo "$line" |cut -d'=' -f1 );
   confValue=$( echo "$line" |cut -d'=' -f2 ); 

   if [[ ${confLabel:0:1} != "#" ]]; then #not a comment

    tmp=${confLabel#*[}   # remove prefix ending in "["
    folder=${tmp%]*}   # remove suffix starting with "]"

    # exit if dangerous folder names in config
    if [[ "~/." == *"$folder"* ]]; then 
        printf "Dangerous config! \n[$folder] is not allowed in .conf\n"; exit; 
    fi;
    
    # clone folders if dont exist
    if [ "$confLabel" = "[$folder]" ]; then 
        if [ -d "$folder" ]; then
            echo "Pulling $folder";
            evaluate "cd $folder"; evaluate "git pull"; evaluate "cd ..";
            clone="";
        else 
            clone=$folder; 
        fi;
    fi;
    
    # clone the folders as per the config file if folder does not exist
    if [ "$confLabel" = "source" ] && [ "$clone" != "" ]; then evaluate $confValue; fi;

    ## TODO ##
    # spin up the postgres docker container
    # connect and create the database as per conf file
    # drop the non-canonical schema's from canonical db
    # execute the schema .sql flyways against the canonical db
    # sqldump the canonical
    # overwrite the canonical repo with revised sql
    # git push -u
    # stop amd rmi container
    # cd .. and rm -rf schema-tool dir if param = --remove-when-done
    
     
  fi;   
           
 done

}

# __Main__
_verbose="1"
_configFile="ss-tool.conf"

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
    
    processConfig $_configFile $_verbose; 
    
    exit 0; 
fi;

echo "Try ss-tool --help for help";
echo "";
#FINIS
