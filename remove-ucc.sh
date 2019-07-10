#!/bin/bash

DEFAULT_PORT=41112
DEFAULT_RPC_PORT=41113
DAEMON_BINARY="uccd"
DAEMON_BINARY_FILE="/usr/local/bin/$DAEMON_BINARY"
DEFAULT_USER="$( pgrep -n $DAEMON_BINARY | xargs -r ps -o uname= -p )"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function checks() 
{
  if [[ $(lsb_release -d) != *Ubuntu* ]]; then
    echo -e "${RED}You are not running Ubuntu. This script is not relevant.${NC}"
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}$0 must be run as root.${NC}"
     exit 1
  fi

  if [ ! -f $DAEMON_BINARY_FILE ]; then
    echo -e "${RED}The UCC daemon is not where it is expected to be, this script is not relevant.${NC}"
    exit 1
  fi
  
  if [ -n "$(pidof $DAEMON_BINARY)" ]; then
    echo -e "${GREEN}The uccd daemon is running. We will stop it before removing process is started.${NC}"
  else
    echo -e "${GREEN}The uccd daemon is currently not running. We try locate the correct username.${NC}"
    sleep 2
    echo -e "${GREEN}Searching for the user and data-directory ...${NC}"
    sleep 2
    DATADIR=$(find /home -type d -name ".ucc" | head -1)
    DATADIRS=$(find /home -type d -name ".ucc")
    if [ -d $DATADIR ]; then
      DEFAULT_USER=$(echo "$DATADIR" | rev | awk -F \/ '{print $2}' | rev)
      echo -e "${GREEN}Found the user: $DEFAULT_USER. We continue with the removal.${NC}"
      echo -e "${GREEN}Found the Data-Dir(s): $DATADIRS.${NC}"
    else
      echo -e "${RED}UCC seems not to be installed and thus the script is not relevant. You can cancel with CTRL+C anytime.${NC}"
    fi  
  fi
}

function ask_user() 
{  
  read -e -p "$(echo -e $YELLOW We found this username that was used to install the UCC service, please change if it is wrong: $NC)" -i $DEFAULT_USER USER_NAME

  if [ -z "$USER_NAME" ]; then
    echo -e "${RED}A username must be provided, so the UCC configuration can be removed.${NC}"
    ask_user
  fi

  if [ -z "$(getent passwd $USER_NAME)" ]; then
    echo -e "${RED}The $USER_NAME username was not found.${NC}"
    ask_user
  fi
}

function remove_user()
{
    echo -e "${GREEN}Removing the $USER_NAME users home directory and user profile.${NC}"
    userdel -r $USER_NAME >/dev/null 2>&1
}

function remove_service()
{
  SERVICE_FILE=/etc/systemd/system/$USER_NAME.service

  echo -e "${GREEN}Stopping the $USER_NAME.service service.${NC}"
  systemctl stop $USER_NAME.service
  sleep 3

  echo -e "${GREEN}Removing the $SERVICE_FILE.${NC}"
  rm -f $SERVICE_FILE
}

function remove_deamon() 
{
  echo -e "${GREEN}Removing the UCC binary files from /usr/local/bin.${NC}"
  
  rm -f /usr/local/bin/ucc*
}

function clean_cron() 
{
  echo -e "${GREEN}Cleaning all UCC related cron jobs.${NC}"

  crontab -l | grep -v '/usr/sbin/logrotate' | crontab -
  crontab -l | grep -v '~/.ucc/clearlog-$USER_NAME.sh' | crontab -
}

function clean_firewall() 
{
  echo -e "${GREEN}Removing default firewall rules for port $DEFAULT_PORT and $DEFAULT_RPC_PORT.${NC}"

  ufw disable >/dev/null 2>&1
  ufw delete allow $DEFAULT_PORT/tcp >/dev/null 2>&1
  ufw delete allow $DEFAULT_RPC_PORT/tcp >/dev/null 2>&1
  
  ufw logging on >/dev/null 2>&1

  echo "y" | ufw enable >/dev/null 2>&1
}

function remove_ucc_folder()
{
  echo -e "${GREEN}Cleaning all UCC files from root home folder.${NC}"

  rm -rf ~/.ucc
}

function cleaup_system() 
{
  ask_user
  remove_service
  remove_deamon
  remove_user
  clean_cron
  clean_firewall
  remove_ucc_folder
  
  echo -e "${GREEN}All files and folders for the UCC masternode have been removed from this server.${NC}"
}

clear

echo
echo -e "========================================================================================================="
echo -e "${RED}"
echo -e "                                        u    u        c       c"
echo    "                                        u    u     c      c"
echo    "                                        u    u     c      c" 
echo -e "                                        uuuuuu        c       c" 
echo                          
echo -e "${NC}"
echo -e "This script removes all trace of the UCC masternode if it was installed using click2install's GitHub"
echo -e "script, by performing the following tasks:"
echo -e " - remove the UCC daemon and cli files"
echo -e " - remove the provided users home folder containing the UCC configuration"
echo -e " - Remove the UCC ports from your firewall so they remain blocked"
echo -e " - Remove the UCC service configuration"
echo -e " - Clean up any cron tasks that were created"
echo
echo -e "this script DOES NOT:"
echo -e " - remove fail2ban"
echo -e " - modify SSH ports"
echo
echo -e "Script created by click2install"
echo -e " - GitHub: https://github.com/UCCNetwork/installscript/"
echo -e " - Discord: click2install#9625"
echo -e " - UCC: UZVPzBSEYeFKCpchjBGr72tC3SMpgvNWSe"
echo 
echo -e "========================================================================================================="
echo
read -e -p "$(echo -e $YELLOW Do you want to continue? [Y/N] $NC)" CHOICE

if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
  exit 1;
fi

checks
cleaup_system

