#!/bin/bash

# initialisation environment variable
export $(cat .env)

# Function
# script name
SCRIPTNAME="initialize-services.sh"
# Choose if script run as root (1=yes 0=no)
ENABLE_VERIF_ROOT=1
# have to check that the script is not already running (1=yes 0=no)
ENABLE_SCRIPT_RUN=0

displaymessage() {
  echo "$*"
}

displaytitle() {
  displaymessage "------------------------------------------------------------------------------"
  displaymessage "$*"
  displaymessage "------------------------------------------------------------------------------"

}
displayerror() {
  echo -e "\r\e[0;31m   [ERROR] \e[0m $*"

}

validemessage() {

 fin=" [y|n]"
 local message=$1$fin
 displaymessage $message
 read REPLY
    case $REPLY in
        Y|y) ;;
        N|n) 
            echo 'sortie'
            exit 0 ;;
        *)
            displayerror "Wrong answer, reply by Y ou N"
            validemessage "Retry";;
    esac
}

# First parameter: ERROR CODE
# Second parameter: MESSAGE
displayerrorandexit() {
  local exitcode=$1
  shift
  displayerror "$*"
  exit $exitcode
}

# First parameter: MESSAGE
# Others parameters: COMMAND (! not |)
displayandexec() {
  local message=$1
  echo -n "[In Progress] $message"
  shift
  $* >> $LOG_FILE 2>&1
  local ret=$?
  if [ $ret -ne 0 ]; then
    echo -e "\r\e[0;31m   [ERROR] \e[0m $message"
    # echo -e "\r   [ERROR] $message"
  else
    echo -e "\r\e[0;32m      [OK] \e[0m $message"
    # echo -e "\r      [OK] $message"
  fi
  return $ret
}

# first parameter : URL
# verify if dns entry exist
verifyDns() {
    resolvedIP=$(nslookup "$1" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
    if [[ -z "$resolvedIP" ]]; then
    echo -e "\r\e[0;31m   [ERROR] \e[0m $1 don't have DNS entry"
    # echo -e "\r   [ERROR] $message"
  else
    echo -e "\r\e[0;32m      [OK] \e[0m $1 have DNS entry"
    # echo -e "\r      [OK] $message"
  fi
}

####       ####
# Preparation #
####       ####
if [ $ENABLE_VERIF_ROOT = 1 ];then
        if [ $EUID -ne 0 ]; then
                displayerror "You don't have execute script as root"
                exit 1
        fi
fi

if [ $ENABLE_SCRIPT_RUN = 1 ];then
        nb_occurence=$(ps -C $SCRIPTNAME | wc -l)
        if [ $nb_occurence = 4 ];then
                displayerror "script already launch"
                exit 1
        fi
fi
# Password Verification
if [ ADMIN_PASSWORD = admin ];then
        displayerror "You don't have change admin password."
        displaymessage "Choose new admin password"
        read ADMIN_PASSWORD
        validemessage "confirm admin password :  $ADMIN_PASSWORD"
        export ADMIN_PASSWORD
fi

if [ HTACCESS_PASSWORD = admin ];then
        displayerror "You don't have change HTACCESS password."
        displaymessage "Choose new HTACCESS password"
        read HTACCESS_PASSWORD
        validemessage "confirm HTACCESS password :  $HTACCESS_PASSWORD"
        export HTACCESS_PASSWORD
fi
# Directory verification

if [ ! -d $DIR_PERSISTANT_FOLDER ];then
displayandexec "Create permanent directory" &mkdir -p $DIR_PERSISTANT_FOLDER
fi




# preparation and verification of the environment

displaytitle 'Configuration Traefik'
displayandexec "Create permanent directory for traefik" &mkdir -p $DIR_PERSISTANT_FOLDER/traefik
displayandexec "Copy configuration file traefik.toml" &cp -f ./traefik/traefik.toml $DIR_PERSISTANT_FOLDER/traefik/
displayandexec "Change value in traefik" &sed -i "s#CLUSTER_DOMAIN#$CLUSTER_DOMAIN#" $DIR_PERSISTANT_FOLDER/traefik/traefik.toml && &sed -i "s#ADMIN_EMAIL#$ADMIN_EMAIL#" $DIR_PERSISTANT_FOLDER/traefik/traefik.toml

displayandexec "Create ACME file" &touch  $DIR_PERSISTANT_FOLDER/traefik/acme.json && chmod 600 $DIR_PERSISTANT_FOLDER/traefik/acme.json


displaytitle 'Create docker network'

displayandexec "Create netwok Docker for traefik" &docker network create traefik-net --scope swarm -d overlay
displayandexec "Create network Docker for Metrics" &docker network create metrics-net --scope swarm -d overlay

displaytitle "Create docker"

displayandexec "CREATING INGRESS SERVICES STACK..." &docker stack deploy --compose-file docker-compose-ingress.yml ingress

displayandexec "CREATING ADMINISTRATION SERVICES STACK..." &docker stack deploy --compose-file docker-compose-admin.yml admin

displayandexec "CREATING METRICS SERVICES STACK..." &docker stack deploy --compose-file docker-compose-metrics.yml metrics

displaytitle 'Check all sub domain name to manage your docker swarm'

displaymessage "Check Traefik managment URL"
verifyDns traefik.$CLUSTER_DOMAIN 

