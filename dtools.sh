#!/bin/bash
# [References]
# https://stackoverflow.com/questions/48086633/simple-logging-levels-in-bash
# https://stackoverflow.com/a/41139446
# https://gist.github.com/hfossli/4368aa5a577742c3c9f9266ed214aa58

# Logging Level configuration works as follows:
# DEBUG - Provides all logging output
# INFO  - Provides all but debug messages
# WARN  - Provides all but debug and info
# ERROR - Provides all but debug, info and warn
#
# SEVERE and CRITICAL are also supported levels as extremes of ERROR
#
scriptLoggingLevel="DEBUG"

C_Clear='\033[0m'
C_Red='\033[0;31m'

function usage() {
  if [ -n "$1" ]; then
    echo -e "${C_Red}Exited: $1${C_Clear}\n";
  fi
  echo "Usage: $0 [-l log-level]"
  echo "  -l, --log-level   The Logging Level"
  echo "                    DEBUG - Provides all logging output"
  echo "                    INFO  - Provides all but debug messages"
  echo "                    WARN  - Provides all but debug and info"
  echo "                    ERROR - Provides all but debug, info and warn"
  echo "                    SEVERE and CRITICAL are also supported levels as extremes of ERROR"
  echo ""
  echo " -p, --pull	    Pull active docker-compose containers"
  echo " -r, --restart	    Restart Active socker-compose containers"
  echo "Example: $0 --log-level INFO"
  exit 1
}

Pull_Con=0
Restart_Con=0

# parse params
while [[ "$#" > 0 ]]; do case $1 in
  -l|--log-level) scriptLoggingLevel="$2"; shift; shift;;
  -p|--pull) Pull_Con=1; shift; shift;;
  -r|--restart) Restart_Con=1; shift; shift;;
  *) usage "Unknown parameter passed: $1"; shift; shift;;
esac; done

if [ "${Pull_Con}" -eq 0 ] && [ "${Restart_Con}" -eq 0 ]; then usage "No Action flag set"; fi;

function logThis() {
        dateTime=$(date --rfc-3339=seconds)
        if [ -n "$2" ]
        then
                IN="$2"
        else
                read IN # This reads a string from stdin and stores it in a variable called IN
        fi
        if [[ -z "$1" || -z "$IN" ]]
        then
                echo "${dateTime} - ERROR : LOGGING REQUIRES A DESTINATION FILE, A MESSAGE AND A PRIORITY, IN THAT ORDER."
                echo "${dateTime} - ERROR : INPUTS WERE: ${1} and ${IN}."
                exit 1
        fi

        logMessage=$(echo "${IN}" | xargs)
        logMessagePriority="${1}"

        declare -A logPriorities=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [SEVERE]=4 [CRITICAL]=5)

        [[ ${logPriorities[$logMessagePriority]} ]] || return 1

        #check if level is enough
        (( ${logPriorities[$logMessagePriority]} < ${logPriorities[$scriptLoggingLevel]} )) && return 2

        echo -e "[${logMessagePriority}] ${dateTime}: ${logMessage}"

}

ValidLogLevels=("DEBUG" "INFO" "WARN" "ERROR" "SEVERE" "CRITICAL")

#check if level exists
if [[ ! " ${ValidLogLevels[@]} " =~ " ${scriptLoggingLevel} " ]]
then
        scriptLoggingLevel="DEBUG"
        logThis "ERROR" "Loglevel is invalid switching to DEBUG"
fi


# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
        logThis "WARN" "This script must be run as root"
        exec sudo /bin/bash "$0" "$@"
fi


Compose_Projects=$(sudo docker ps --filter "label=com.docker.compose.project" -q | xargs -I {} sudo docker container inspect {} --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' | uniq)

Count=$(echo "${Compose_Projects}" | grep -c '^')

logThis "DEBUG" "${Count} containers found"

for working_dir in ${Compose_Projects}; do
	if [ "${Pull_Con}" -eq 1 ]
	then
		logThis "INFO" "Pulling ${working_dir}"
		(cd "$working_dir" && docker-compose pull) 2>&1 | logThis "INFO"
	fi
        if [ "${Restart_Con}" -eq 1 ]
        then
                logThis "INFO" "Restarting ${working_dir}"
                (cd "$working_dir" &&  docker-compose down && docker-compose up -d) 2>&1 | logThis "INFO"
        fi

done
