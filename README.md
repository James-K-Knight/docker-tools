# docker-tools

Simple docker helper scripts that pulls/restarts all containers running via docker-compose files.

```bash
Usage: dtools [-l log-level][-p/-r/-w][a]
 -l                     The Logging Level
                        DEBUG - Provides all logging output
                        INFO  - Provides all but debug messages
                        WARN  - Provides all but debug and info
                        ERROR - Provides all but debug, info and warn
                        SEVERE and CRITICAL are also supported levels as extremes of ERROR

 -p                     Pull active docker-compose containers
 -r                     Restart active docker-compose containers
 -w                     Outputs simlinks to docker-compose config files in ${Active_DIR}
 -a                     Only uses docker-compose config files in ${Active_DIR}
Example: dtools.sh -l INFO -p
```
