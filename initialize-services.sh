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

DATE=`date +"%Y%m%d%H%M%S"`
TEMP_FOLDER="/tmp/$SCRIPTNAME.$DATE"
LOG_FOLDER="/tmp/"
LOG_FILE="$LOG_FOLDER$SCRIPTNAME-$DATE.log"

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
if [ "$ADMIN_PASSWORD" = "adminUser" ];then
        displayerror "You don't have change admin password."
        displaymessage "Choose new admin password"
        read ADMIN_PASSWORD
        validemessage "confirm admin password :  $ADMIN_PASSWORD"
        export ADMIN_PASSWORD=$ADMIN_PASSWORD
        sed -i "s#adminUser#$ADMIN_PASSWORD#" ./.env

fi
export ADMIN_PASSWORD_CRYPT=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin $ADMIN_PASSWORD | cut -d ":" -f 2 )
export ADMIN_PASSWORD_CRYPT_SHA256=$(echo $ADMIN_PASSWORD | sha256sum | cut -d" " -f1)

if [ "$HTACCESS_PASSWORD" = "adminHtaccess" ];then
        displayerror "You don't have change HTACCESS password."
        displaymessage "Choose new HTACCESS password"
        read HTACCESS_PASSWORD
        validemessage "confirm HTACCESS password :  $HTACCESS_PASSWORD"
        sed -i "s#adminHtaccess#$HTACCESS_PASSWORD#" ./.env
fi
        export HTACCESS_PASSWORD_CRYPT=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin $HTACCESS_PASSWORD | cut -d ":" -f 2 )


if [ "$CLUSTER_DOMAIN" = "mycluster.org" ];then
        displayerror "You don't have change your domain name."
        displaymessage "Choose new domaine name (without www.)"
        read CLUSTER_DOMAIN
        validemessage "confirm Domaine Name :  $CLUSTER_DOMAIN"
        export CLUSTER_DOMAIN=$CLUSTER_DOMAIN
        sed -i "s#mycluster.org#$CLUSTER_DOMAIN#" ./.env
fi

if [ $RANDOM_SECRET = changeit ];then
displayandexec "Generate random secret" &export RANDOM_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sed -i "s#changeit#$RANDOM_SECRET#" ./.env
fi

# Directory verification

if [ ! -d $DIR_PERSISTANT_FOLDER ];then
displayandexec "Create permanent directory" &mkdir -p $DIR_PERSISTANT_FOLDER
fi

# find docker gateway to environment variable dockerd-exporter
export DOCKER_GWBRIDGE_IP=$(docker run --rm --net host alpine ip -o addr show docker_gwbridge | grep 'inet ' | cut -d " " -f 7 | cut -d"/" -f 1)



# preparation and verification of the environment

displaytitle 'Configuration Traefik'
displayandexec "Create permanent directory for Traefik" &mkdir -p $DIR_PERSISTANT_FOLDER/traefik
displayandexec "Copy configuration file traefik.toml" &cp -f ./traefik/traefik.toml $DIR_PERSISTANT_FOLDER/traefik/
displayandexec "Change value in Traefik" &sed -i "s#CLUSTER_DOMAIN#$CLUSTER_DOMAIN#" $DIR_PERSISTANT_FOLDER/traefik/traefik.toml && sed -i "s#ADMIN_EMAIL#$ADMIN_EMAIL#" $DIR_PERSISTANT_FOLDER/traefik/traefik.toml
displayandexec "Create ACME file" &touch  $DIR_PERSISTANT_FOLDER/traefik/acme.json && chmod 600 $DIR_PERSISTANT_FOLDER/traefik/acme.json
displayandexec "Create persist Portainer folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/portainer
displayandexec "Create persist alertmanager folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/alertmanager
displayandexec "Create persist grafana folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/grafana
displayandexec "Create persist elasticsearch folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/elasticsearch
displayandexec "Create persist mongo folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/mongo
displayandexec "Create persist graylog folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/graylog
displayandexec "Create persist gitlab-runner folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/gitlab-runner/{etc,home}
displayandexec "Create persist gitlab folder"  &mkdir -p $DIR_PERSISTANT_FOLDER/gitlab/{etc,opt,log}



displaytitle 'Create docker network'

displayandexec "Create netwok Docker for Traefik" &docker network create traefik-net --scope swarm -d overlay --opt encrypted=true
displayandexec "Create network Docker for Metrics" &docker network create metrics-net --scope swarm -d overlay --opt encrypted=true
displayandexec "Create network Docker for Admin" &docker network create admin-net --scope swarm -d overlay --opt encrypted=true


displaytitle "Create docker"

sleep 2
displayandexec "CREATING INGRESS SERVICES STACK..." &docker stack deploy --compose-file docker-compose-ingress.yml ingress

displayandexec "CREATING LOGS SERVICES STACK..." &docker stack deploy --compose-file docker-compose-log.yml logs
sleep 5
displayandexec "CREATING ADMINISTRATION SERVICES STACK..." &docker stack deploy --compose-file docker-compose-admin.yml admin

displayandexec "CREATING METRICS SERVICES STACK..." &docker stack deploy --compose-file docker-compose-metrics.yml metrics


displaytitle 'Check all sub domain name to manage your docker swarm'

displaymessage "Check Graylog managment URL"
verifyDns graylog.$CLUSTER_DOMAIN 
displaymessage "Check Traefik managment URL"
verifyDns traefik.$CLUSTER_DOMAIN 
displaymessage "Check portainer managment Docker URL"
verifyDns portainer.$CLUSTER_DOMAIN 
displaymessage "Check Feeds managment URL"
verifyDns feeds.$CLUSTER_DOMAIN 
displaymessage "Check Grafana managment URL"
verifyDns grafana.$CLUSTER_DOMAIN 
displaymessage "Check Dashboard managment URL"
verifyDns dashboard.$CLUSTER_DOMAIN prometheus
displaymessage "Check Prometheus managment URL"
verifyDns prometheus.$CLUSTER_DOMAIN
