#!/bin/bash

TMP_FOLDER=$(mktemp -d)
BINARY_LINK="https://github.com/UCCNetwork/ucc/releases/download/v2.2.0.0/UCC-2.2.0.0-Linux64bit.zip"
INSTALL_LINK=https://github.com/UCCNetwork/installscript/raw/master/install_ucc_binary.sh
INSTALL_FILE=install_ucc_binary.sh
DAEMON_BINARY="uccd"
CLI_BINARY="ucc-cli"
DAEMON_BINARY_FILE="/usr/local/bin/$DAEMON_BINARY"
CLI_BINARY_FILE="/usr/local/bin/$CLI_BINARY"
DEFAULT_USER="$( pgrep -n $DAEMON_BINARY | xargs -r ps -o uname= -p )"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function load_installer() 
{
  wget -q $INSTALL_LINK && bash $INSTALL_FILE
  exit 0
}

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
  
  if [ -n "$(pidof $DAEMON_BINARY)" ]; then
    echo -e "${GREEN}The uccd daemon is already running. We will update it.${NC}"
  else
    echo -e "${RED}The uccd daemon is currently not running. We try update it.${NC}"
    sleep 2
    echo -e "${RED}Searching for the user and data-directoy ...${NC}"
    sleep 2
    DATADIR=$(find /home -type d -name ".ucc")
    if [ -d $DATADIR ]; then
      DEFAULT_USER=$(echo "$DATADIR" | rev | awk -F \/ '{print $2}' | rev)
      echo -e "${GREEN}Found the user: $DEFAULT_USER. We continue with the update.${NC}"
    else
      echo -e "${RED}UCC seems not to be installed.${NC}"
      read -e -p "$(echo -e $YELLOW Should we fetch the install-script and install a new masternode? [Y/N] $NC)" ICHOICE
      if [[ ("$ICHOICE" == "n" || "$ICHOICE" == "N") ]]; then
        exit 1;
      else
       load_installer
      fi
    fi  
  fi
}

function stop_service() 
{
  echo -e "${GREEN}Stopping UCC Masternode ... this takes some time ...${NC}"
  sleep 2
  systemctl stop "$USER_NAME"
}

function start_service() 
{
  echo -e "${GREEN}Starting UCC Masternode ...${NC}"
  sleep 5
  systemctl start "$USER_NAME"
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
  chmod 755 $DAEMON_BINARY_FILE
  chmod 755 $CLI_BINARY_FILE
}

function ask_user() 
{ 
  read -e -p "$(echo -e $YELLOW We found this user running the Masternode. Please change if it is not correct:  $NC)" -i $DEFAULT_USER USER_NAME

  if [ -z "$(getent passwd $USER_NAME)" ]; then
    echo -e "${RED}User does not yet exist. Please enter the correct username.${NC}"
    ask_user
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
