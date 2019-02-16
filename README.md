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
* it spins up a postgres:latest docker image and creates an instance of the \[canonical-database\]
* it then drops the schemas in the **canonical-database** for micro-service schema which exists
* it uses a transient docker image boxfuse/flyway:latest to exceute the migration scripts from each microservice
* it the does a pg_dump of the canonical-database sql and commits it back to the canonical git repository

if the --cleanup flag is not used the updated cannonical database can be accessed
on localhost:9432 using psql or pgadmin etc. with the username=postgres and password=postgress

you can manualy remove the database when done with:
<pre>
docker stop db
docker rm db
</pre>

Dependencies:
* docker
* postgres - makes use of pg_dump & psql 

(C)Copyright 2019, bank-builder
License: MIT
