# ss-tool
schema-sync tool for syncing postgres schemas 
from multiple micro-service repositories 
into a single canonical database

<pre>
Usage: ss-tool [OPTION]...
   Clones the repositories of multiple micro-services as per the ss-tool.conf file
   and drops & recreates these discrete schemas into a single canonical database
   which it then round-trips back into the canonical repository
 
  OPTIONS:
    -f, --file      supply optional file name of alternative ss-tool.conf file
    -s, --silent    does not display verbose details
    -c, --cleanup   removes all git cloned sub-directories & docker db when done
    -g, --git-ref   add an optional custom git reference eg 243 to match issue 243
    -p, --push-git  push to GitHub, default behaviour creates branch but does not push
        --help      display this help and exit
        --version   display version and exit


  EXAMPLE(s):
      ss-tool --cleanup -g 243
           will remove all git cloned repositories & docker db when done
           and add a git-ref of '243-ss_tool-db-auto-update' when pushing the changes

      ss-tool.conf:
          [canonical-database] section
          [<microservice>] section(s) giving details of repo with amongst other settings, 
                           the source path to the Flyway SQL scripts for
                           the micro-service schemas

</pre>

The ss-tool does the following:
* it clones all the github repos for the listed micro-services
* it spins up a postgres:latest docker image and creates an instance of the \[canonical-database\]
* it then drops the schemas in the **canonical-database** for micro-service schema which exists
* it uses a transient docker image flyway/flyway:latest to execute the migration scripts from each micro-service
* it the does a pg_dump of the canonical-database sql and commits it back to the canonical git repository

if the --cleanup flag is not used the updated canonical database can be accessed
on localhost:9432 using psql or pgadmin etc. with the username=postgres and password=postgres

you can manually remove the database when done with:
<pre>
docker-compose down -v --remove-orphans
</pre>

Dependencies:
* docker
* docker-compose

Copyright &copy; 2019, bank-builder

License: MIT and ![CC 4.0](https://licensebuttons.net/l/by/4.0/88x31.png)
