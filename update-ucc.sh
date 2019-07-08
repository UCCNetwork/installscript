#!/bin/bash

TMP_FOLDER=$(mktemp -d)
BINARY_LINK="https://github.com/UCCNetwork/ucc/releases/download/v2.2.0.0/UCC-2.2.0.0-Linux64bit.zip"
DEFAULT_USER="$( pgrep -n '$DAEMON_BINARY' | xargs -r ps -o uname= -p )"
DAEMON_BINARY="uccd"
CLI_BINARY="ucc-cli"
DAEMON_BINARY_FILE="/usr/local/bin/$DAEMON_BINARY"
CLI_BINARY_FILE="/usr/local/bin/$CLI_BINARY"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function checks() 
{
  if [[ $(lsb_release -d) != *Ubuntu* ]]; then
    echo -e "${RED}You are not running Ubuntu. Installation is cancelled.${NC}"
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}$0 must be run as root.${NC}"
     exit 1
  fi
}

function stop_service() 
{
  clear
  echo -e "${GREEN}Stopping UCC Masternode ...${NC}"
  systemctl stop "$USER_NAME"
}

function start_service() 
{
  clear
  echo -e "${GREEN}Starting UCC Masternode ...${NC}"
  systemctl start "$USER_NAME"
  sleep 5
}

function update_binary() 
{ 
  cd "$TMP_FOLDER"
  mkdir ucc_binary && cd ucc_binary
  echo -e "${GREEN}Downloading UCC Binary from Github ...${NC}"
  wget $BINARY_LINK
  sleep 3
  unzip UCC*
  cd UCC*
  echo -e "${GREEN}Replacing the UCC Binary with newer Version ...${NC}"
  cp -a $DAEMON_BINARY $DAEMON_BINARY_FILE
  cp -a $CLI_BINARY $CLI_BINARY_FILE
}

function ask_user() 
{ 
  read -e -p "$(echo -e $YELLOW We found this user running the Masternode. Please change if it is not correct:  $NC)" -i $DEFAULT_USER USER_NAME

  if [ -z "$(getent passwd $USER_NAME)" ]; then
    clear
    echo -e "${RED}User does not yet exist. Please enter the correct username.${NC}"
    ask_user
  else
    clear
  fi
}

function show_output() 
{
 echo
 echo -e "================================================================================================================================"
 echo
 echo -e "${GREEN}Your UCC master node was updated!${NC}" 
 echo
 echo -e "You can manage your UCC service from your SSH cmdline with the following commands:"
 echo -e " - ${GREEN}systemctl start $USER_NAME.service${NC} to start the service."
 echo -e " - ${GREEN}systemctl stop $USER_NAME.service${NC} to stop the service."
 echo -e " - ${GREEN}systemctl status $USER_NAME.service${NC} to get the status of the service."
 echo
 echo -e "You can find the masternode status when logged in as $USER_NAME using the command below:"
 echo -e " - ${GREEN}${CLI_BINARY} getinfo${NC} to retrieve your nodes status and information"
 echo
 echo -e "  if you are not logged in as $USER_NAME then you can run ${YELLOW}su - $USER_NAME${NC} to switch to that user before"
 echo -e "  running the ${GREEN}getinfo${NC} command."
 echo -e "  NOTE: the deamon must be running first before trying this command. See notes above on service commands usage."
 echo 
 echo -e "You can run ${GREEN}htop${NC} if you want to verify the UCC service is running or to monitor your server."
 echo 
 echo -e "================================================================================================================================"
 echo
}

clear

echo
echo -e "========================================================================================================="
echo -e "${GREEN}"
echo -e "                                        u   u       c       c"
echo    "                                        u   u    c       c"
echo    "                                        u   u    c       c" 
echo -e "                                        uuuud       c       c" 
echo                          
echo -e "${NC}"
echo -e "This script will automate the update of your UCC masternode by"
echo -e "performing the following steps:"
echo
echo -e " - Obtain the latest UCC masternode files from the UCC GitHub repository"
echo -e " - Check the current user which runs actually the UCC masternode service"
echo -e " - Stop the UCC masternode service"
echo -e " - update the UCC masternode binaries"
echo -e " - Start the UCC masternode service"
echo
echo -e "The script will output ${YELLOW}questions${NC}, ${GREEN}information${NC} and ${RED}errors${NC}"
echo -e "When finished the script will show a summary of what has been done."
echo
echo -e "Script created by fly"
echo -e " - GitHub: https://github.com/UCCNetwork/installscript/"
echo 
echo -e "========================================================================================================="
echo
read -e -p "$(echo -e $YELLOW Do you want to continue? [Y/N] $NC)" CHOICE

if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
  exit 1;
fi

checks

ask_user
stop_service
update_binary
start_service
show_output
