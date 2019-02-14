# ss-tool
schema-sync tool for synching postgres schemas 
from multiple micro-service repositories 
into a single canonical database

<pre>
Usage: ss-tool [OPTION]...
   Clones the repositories of multiple microservices as per the ss.conf file
   and drops & recreates these discrete schemas into a single canonical database
   which it then round-trips back into the canonical repository
 
  OPTIONS:
    -f, --file      supply optional file name of alternative ss-tool.conf file
    -s, --silent    does not display vebose details
    -c, --cleanup   removes all git cloned sub-directories & docker db when done
        --help      display this help and exit
        --version   display version and exit


  EXAMPLE(s):
      ss-tool --cleanup
           will remove all git cloned repositories & docker db when done

      ss-tool.conf:
          [canonical-database] section
          [<microservice>] section(s) giving details of repo with amongst other settings, 
                           the source path to the FlyWay SQL scripts for
                           the micro-service schemas
</pre>

The ss-tool does the following:
* it clones all the github repos for the listed microservices
* it spins up a postgres docker image and creates an instance of the \[canonical-database\]
* it then drops the schemas in the **canonical-database** for which micro-service schema's exist
* it rebuilds as per the micro-service schema sql file(s) (assuming FlyWay compatible SQL files)
* it the does a pgdump of the canonical-database sql and commits it back to the canonical repository

Dependencies:
* docker
<pre>sudo apt install docker.io</pre>
* postgres client

(C)Copyright 2019, bank-builder
License: MIT
