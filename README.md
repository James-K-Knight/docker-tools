# docker-tools

Simple docker helper script that pulls/restarts all containers running via docker-compose files.

```bash
Usage: dtools.sh [-l log-level][-p/-r/-w][a]
 -l                     The Logging Level
                        DEBUG - Provides all logging output
                        INFO  - Provides all but debug messages
                        WARN  - Provides all but debug and info
                        ERROR - Provides all but debug, info and warn
                        SEVERE and CRITICAL are also supported levels as extremes of ERROR

 -p                     Pull active docker-compose containers
 -r                     Restart active docker-compose containers
 -w                     Outputs simlinks to docker-compose config files in /opt/active
 -a                     Only uses docker-compose config files in /opt/active
Example: dtools.sh -l INFO -p
```

## Configuration

There are two configuration lines in the script, the default log level and the output directory for the simlinks produced with the `-w` flag.

```
scriptLoggingLevel="DEBUG"

Active_DIR="/opt/active"
```

