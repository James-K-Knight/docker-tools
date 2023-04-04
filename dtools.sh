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

Active_DIR="/opt/active"

C_Clear='\033[0m'
C_Red='\033[0;31m'

function usage() {
  if [ -n "$1" ]; then
    echo -e "${C_Red}Exited: $1${C_Clear}\n";
  fi
  echo "Usage: $0 [-l log-level]"
  echo " -l 			The Logging Level"
  echo "			DEBUG - Provides all logging output"
  echo "			INFO  - Provides all but debug messages"
  echo "			WARN  - Provides all but debug and info"
  echo "			ERROR - Provides all but debug, info and warn"
  echo "			SEVERE and CRITICAL are also supported levels as extremes of ERROR"
  echo ""
  echo " -p			Pull active docker-compose containers"
  echo " -r			Restart active docker-compose containers"
  echo " -w			Outputs simlinks to docker-compose config files in ${Active_DIR}"
  echo " -a			Only uses docker-compose config files in ${Active_DIR}"
  echo "Example: $0 --log-level INFO"
  exit 1
}

unset -v Pull_Con
unset -v Restart_Con
unset -v Lnk_Con
unset -v Acc_Con

ValidLogLevels=("DEBUG" "INFO" "WARN" "ERROR" "SEVERE" "CRITICAL")

# parse params
while getopts ":l:prwa" opt; do
    case "${opt}" in
        l)
		scriptLoggingLevel=${OPTARG}
		#check if level exists
		if [[ ! " ${ValidLogLevels[@]} " =~ " ${scriptLoggingLevel} " ]]
		then
		        scriptLoggingLevel="DEBUG"
		        logThis "ERROR" "Loglevel is invalid switching to DEBUG"
		fi
		;;
        p)
            Pull_Con=1
            ;;
        r)
            Restart_Con=1
            ;;
        w)
            Lnk_Con=1
            ;;
        a)
            Acc_Con=1
            ;;
        *)
            usage "Unknown parameter passed: ${OPTARG}"
            ;;
    esac
done

if [ -z $Pull_Con ] && [ -z $Restart_Con ] && [ -z $Lnk_Con ]; then
	usage "No Action flag set"
fi

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

function pipeThis() {
	while read IN
	do
		logThis "${1}" "${IN}"
	done
}

ValidLogLevels=("DEBUG" "INFO" "WARN" "ERROR" "SEVERE" "CRITICAL")

#check if level exists
if [[ ! " ${ValidLogLevels[@]} " =~ " ${scriptLoggingLevel} " ]]
then
        scriptLoggingLevel="DEBUG"
        logThis "ERROR" "Loglevel is invalid switching to DEBUG"
fi


# Make sure only docker group members or a superuser can run our script
if [[ ! $(id | grep "docker") && $EUID -ne 0 ]]; then
        logThis "WARN" "This script must be run as root"
        exec sudo /bin/bash "$0" "$@"
fi

type docker 2>&1 | logThis "DEBUG"
type docker-compose 2>&1 | logThis "DEBUG"

if [ -z "${Lnk_Con}" ] && [ -n "${Acc_Con}" ]
then
	logThis "INFO" "Reading from ${Active_DIR}"
	Compose_Projects=($(ls "${Active_DIR}/"*.yaml))
else
	docker_containers=$(sudo docker ps --filter "label=com.docker.compose.project" -q)
	Compose_Projects=()
	for container in ${docker_containers}; do
		Compose_Projects+=("$(echo ${container} | xargs -I {} sudo docker container inspect {} --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}')/$(echo ${container} | xargs -I {} sudo docker container inspect {} --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}')")
	done
fi
Compose_Projects=$(for project in "${Compose_Projects[@]}"; do echo "$(readlink -f ${project})"; done | uniq)

logThis "DEBUG" "${#Compose_Projects[@]} containers found"

if [ -n "${Lnk_Con}" ] && [ ! -d "${Active_DIR}" ]
then
	logThis "DEBUG" "Creating ${Active_DIR}"
	mkdir -p "${Active_DIR}"
fi
for compose_file in ${Compose_Projects}; do
	working_dir=$(dirname "${compose_file}")
	logThis "DEBUG" "Working directory ${working_dir}"
	if [ -n "${Lnk_Con}" ]
	then
		project_name=$(basename "${working_dir}")
		logThis "DEBUG" "Compose file ${compose_file}"
		logThis "DEBUG" "Destination simlink ${Active_DIR}/${project_name}.yaml"
		ln -s "${compose_file}" "${Active_DIR}/${project_name}.yaml"
	fi
	if [ -n "${Pull_Con}" ]
	then
		logThis "INFO" "Pulling ${working_dir}"
		cd "$working_dir"
		docker-compose --ansi never pull 2>&1 | pipeThis "DEBUG"
	fi
        if [ -n "${Restart_Con}" ]
        then
                logThis "INFO" "Restarting ${working_dir}"
		cd "$working_dir"
		docker-compose --ansi never down 2>&1 | pipeThis "DEBUG"
		docker-compose --ansi never up -d 2>&1 | pipeThis "DEBUG"
        fi

done
