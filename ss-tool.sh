#!/bin/bash
# Copyright (c) 2018, Andrew Turpin
# License MIT: https://opensource.org/licenses/MIT
# Schema Sync - known as ss, is a tool to sync the postgres schemas from 
#               multiple microservices into a single cannonical view
#-----------------------------------------------------------------------


_version="0.1"

function displayHelp(){
 echo "Usage ss-tool [OPTION]... [FILE]";
 echo "   Clones the repositories of multiple microservices as per the ss.conf file";
 echo "   and drops & recreates these discrete schemas into a single canonical database";
 echo "   which it then round-trips back into the canonical repository";
 echo " ";
 echo "  OPTIONS:";
 echo "    -f, --file      supply file name of the ss.conf";
 echo "                    the default is ss.conf in the current path";
 echo "    -v, --verbose   display vebose details and progress bar.  Works with -f option only.";
 echo "    -c, --cleanup   removes the current directory & all sub-directories when done, leaving no trace.";
 echo "        --help      display this help and exit";
 echo "        --version   display version and exit";
 echo "Usage ss [OPTION]... [FILE]";
 echo "";
 echo "  EXAMPLE(s):";
 echo "      ss-tool -f [ss-tool.conf]";
 echo "";
 echo "      ss-tool.conf:";
 echo "          [canonical-database] section";
 echo "          [<microservice>] section(s) giving details of repo with flyway sql to build micro-service schemas";
 echo "";
}

function displayVersion(){
 echo "ss-tool (bank-builder utils) version $_version";
 echo "Copyright (C) 2019, Andrew Turpin";
 echo "License MIT: https://opensource.org/licenses/MIT";
 echo "";
}

function processConfig(){
    Config="$1"
    
    IFS=$'\n'
    total=`cat $Config | wc -l`
    number=1
    
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
                    eval "cd $folder"; eval "git pull"; eval "cd ..";
                    clone="";
                else 
                    clone=$folder; 
                fi;
            fi;
            
            # clone the folders as per the config file if folder does not exist
            if [ "$confLabel" = "source" ] && [ "$clone" != "" ]; then eval $confValue; fi;
  
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
_verbose="0"
_markdown="0"
while [[ "$#" > 0 ]]; do
    case $1 in
        --help) 
            displayHelp; exit 0;;
        --version) 
            displayVersion; exit 0;;
        -f|--file) 
            _confileFile="$2";
            shift;;
        -v|--verbose) 
            _verbose="1"
            ;;
        -c|--cleanup) 
            _cleanup="1";
            shift;
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1;;
    esac; 
    shift; 
done

if [ "$_verbose" = "1" ]; then 
    _title="ss-tool ver $_version";
    if [ "$_markdown" = "1" ]; then _title="# $_title";
    else _title="$_title\n======================";
    fi;
    echo -e $_title
fi


if [ -n "$_configFile" ]; then processConfig $_configFile $_verbose $_markdown;exit 0; fi;

echo "Try ss-tool --help for help";
#FINIS
