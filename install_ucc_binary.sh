#!/bin/bash

TMP_FOLDER=$(mktemp -d)
BINARY_LINK="https://github.com/UCCNetwork/ucc/releases/download/v2.2.0.0/UCC-2.2.0.0-Linux64bit.zip"
UPDATE_LINK=https://github.com/UCCNetwork/installscript/raw/master/update-ucc.sh
UPDATE_FILE=update-ucc.sh
CONFIG_FILE="ucc.conf"
DEFAULT_USER="ucc-mn1"
DEFAULT_PORT=41112
DEFAULT_RPC_PORT=41113
DEFAULT_SSH_PORT=22
DAEMON_BINARY="uccd"
CLI_BINARY="ucc-cli"
DAEMON_BINARY_FILE="/usr/local/bin/$DAEMON_BINARY"
CLI_BINARY_FILE="/usr/local/bin/$CLI_BINARY"
GITHUB_REPO="https://github.com/UCCNetwork/ucc.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function load_updater() 
{
  wget -q $UPDATE_LINK && bash $UPDATE_FILE
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
    echo -e "${RED}The uccd daemon is already running. We support no multiple instances on one host.${NC}"
    sleep 2
    read -e -p "$(echo -e $YELLOW Should we fetch the update-script instead and update the masternode? [Y/N] $NC)" ICHOICE
    if [[ ("$ICHOICE" == "n" || "$ICHOICE" == "N") ]]; then
      exit 1;
    else
      load_updater
    fi
  else
    NEW_NODE="new" 
  fi
}

function prepare_system() 
{
  clear
  echo -e "Checking if swap space is required."
  PHYMEM=$(free -g | awk '/^Mem:/{print $2}')
  
  if [ "$PHYMEM" -lt "2" ]; then
    SWAP=$(swapon -s get 1 | awk '{print $1}')
    if [ -z "$SWAP" ]; then
      echo -e "${GREEN}Server is running without a swap file and less than 2G of RAM, creating a 4G swap file.${NC}"
      dd if=/dev/zero of=/swapfile bs=1024 count=4M
      chmod 600 /swapfile
      mkswap /swapfile
      swapon -a /swapfile
      echo "/swapfile    none    swap    sw    0   0" >> /etc/fstab
    else
      echo -e "${GREEN}Swap file already exists.${NC}"
    fi
  else
    echo -e "${GREEN}Server is running with at least 2G of RAM, no swap file needed.${NC}"
  fi
  
  echo -e "${GREEN}Updating package manager${NC}."
  apt update
  
  echo -e "${GREEN}Upgrading existing packages, it may take some time to finish.${NC}"
  DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade 
  
  echo -e "${GREEN}Installing all dependencies for the UCC master node, it may take some time to finish.${NC}"
  apt install -y sudo git wget pwgen fail2ban ufw htop unzip
  apt autoremove -y
  apt autoclean -y
}

function deploy_binary() 
{
  cd "$TMP_FOLDER"
  mkdir ucc_binary && cd ucc_binary
  wget $BINARY_LINK
  sleep 2
  unzip UCC*
  rm *.zip
  cd UCC*
  cp -a $DAEMON_BINARY $DAEMON_BINARY_FILE
  cp -a $CLI_BINARY $CLI_BINARY_FILE
  chmod 755 $DAEMON_BINARY_FILE
  chmod 755 $CLI_BINARY_FILE
}

function enable_firewall() 
{
  echo -e "${GREEN}Setting up firewall to allow access on port $DAEMON_PORT.${NC}"

  apt install ufw -y >/dev/null 2>&1

  ufw disable >/dev/null 2>&1
  ufw allow $DAEMON_PORT/tcp comment "UCC Masternode port" >/dev/null 2>&1
  ufw allow $DEFAULT_RPC_PORT/tcp comment "UCC Masernode RPC port" >/dev/null 2>&1
  
  ufw allow $SSH_PORTNUMBER/tcp comment "Custom SSH port" >/dev/null 2>&1
  ufw limit $SSH_PORTNUMBER/tcp >/dev/null 2>&1

  ufw logging on >/dev/null 2>&1
  ufw default deny incoming >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1

  echo "y" | ufw enable >/dev/null 2>&1

  echo -e "${GREEN}Setting up fail2ban for additional server security."
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function add_daemon_service() 
{
  cat << EOF > /etc/systemd/system/$USER_NAME.service
[Unit]
Description=UCC deamon service
After=network.target
After=syslog.target
[Service]
Type=forking
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$DATA_DIR
ExecStart=$DAEMON_BINARY_FILE -- -datadir=$DATA_DIR -conf=$DATA_DIR/ucc.conf -daemon
ExecStop=$CLI_BINARY_FILE -- -datadir=$DATA_DIR -conf=$DATA_DIR/ucc.conf stop
Restart=always
RestartSec=3
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3

  echo -e "${GREEN}Starting the UCC service from $DAEMON_BINARY_FILE on port $DAEMON_PORT.${NC}"
  systemctl start $USER_NAME.service >/dev/null 2>&1
  
  echo -e "${GREEN}Enabling the service to start on reboot.${NC}"
  systemctl enable $USER_NAME.service >/dev/null 2>&1

  if [[ -z $(pidof $DAEMON_BINARY) ]]; then
    echo -e "${RED}The UCC masternode service is not running${NC}. You should start by running the following commands as root:"
    echo "systemctl start $USER_NAME.service"
    echo "systemctl status $USER_NAME.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function ask_port() 
{
  read -e -p "$(echo -e $YELLOW Enter a port to run the UCC service on: $NC)" -i $DEFAULT_PORT DAEMON_PORT
}

function ask_user() 
{  
  read -e -p "$(echo -e $YELLOW Enter a new username to run the UCC service as: $NC)" -i $DEFAULT_USER USER_NAME

  if [ -z "$(getent passwd $USER_NAME)" ]; then
    useradd -m $USER_NAME
    USER_PASSWORD=$(pwgen -s 12 1)
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd

    home_dir=$(sudo -H -u $USER_NAME bash -c 'echo $HOME')
    DATA_DIR="$home_dir/.ucc"
        
    mkdir -p $DATA_DIR
    chown -R $USER_NAME: $DATA_DIR >/dev/null 2>&1
    
    sudo -u $USER_NAME bash -c : && RUNAS="sudo -u $USER_NAME"
  else
    clear
    echo -e "${RED}User already exists. Please enter another username.${NC}"
    ask_user
  fi
}

function check_port() 
{
  declare -a PORTS

  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $DAEMON_PORT ]] || [[ ${PORTS[@]} =~ $[DEFAULT_RPC_PORT] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function ask_ssh_port()
{
  read -e -p "$(echo -e $YELLOW Enter a port for SSH connections to your VPS: $NC)" -i $DEFAULT_SSH_PORT SSH_PORTNUMBER

  sed -i "s/[#]\{0,1\}[ ]\{0,1\}Port [0-9]\{2,\}/Port ${SSH_PORTNUMBER}/g" /etc/ssh/sshd_config
  systemctl reload sshd
}

function create_config() 
{
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  DAEMON_IP=$(curl -s http://whatismyip.akamai.com/)  
  cat << EOF > $DATA_DIR/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$DEFAULT_RPC_PORT
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
port=$DAEMON_PORT
externalip=$DAEMON_IP
bind=0.0.0.0
EOF
}

function create_key() 
{
  read -e -p "$(echo -e $YELLOW Enter your master nodes private key. Leave it blank to generate a new private key.$NC)" PRIV_KEY

  if [[ -z "$PRIV_KEY" ]]; then
    sudo -u $USER_NAME $DAEMON_BINARY_FILE -datadir=$DATA_DIR -daemon >/dev/null 2>&1
    sleep 25

    if [ -z "$(pidof $DAEMON_BINARY)" ]; then
    echo -e "${RED}UCC deamon couldn't start, could not generate a private key. Check /var/log/syslog for errors.${NC}"
    exit 1
    fi

    PRIV_KEY=$(sudo -u $USER_NAME $CLI_BINARY_FILE -datadir=$DATA_DIR masternode genkey) 
    sudo -u $USER_NAME $CLI_BINARY_FILE -datadir=$DATA_DIR stop >/dev/null 2>&1
  fi
}

function update_config() 
{
  cat << EOF >> $DATA_DIR/$CONFIG_FILE
masternode=1
masternodeaddr=$DAEMON_IP:$DAEMON_PORT
masternodeprivkey=$PRIV_KEY
EOF
  chown $USER_NAME: $DATA_DIR/$CONFIG_FILE >/dev/null
}

function add_log_truncate()
{
  LOG_FILE="$DATA_DIR/debug.log";

  mkdir ~/.ucc >/dev/null 2>&1
  cat << EOF >> $DATA_DIR/logrotate.conf
$DATA_DIR/*.log {
    rotate 4
    weekly
    compress
    missingok
    notifempty
}
EOF

  if ! crontab -l | grep "/home/$USER_NAME/logrotate.conf"; then
    (crontab -l ; echo "1 0 * * 1 /usr/sbin/logrotate $DATA_DIR/logrotate.conf --state $DATA_DIR/logrotate-state") | crontab -
  fi
}

function show_output() 
{
 echo
 echo -e "================================================================================================================================"
 echo
 echo -e "${GREEN}Your UCC master node is up and running.${NC}" 
 echo
 echo -e "${YELLOW}It is recommended that you copy/paste all of this information and keep it in a safely kept file on your local PC"
 echo -e "so you know how to use the commands below to manage your UCC master node.${NC}"
 echo
 echo -e " - it is running as user ${GREEN}$USER_NAME${NC} and it is listening on port ${GREEN}$DAEMON_PORT${NC} at your VPS address ${GREEN}$DAEMON_IP${NC}."
 echo -e " - the ${GREEN}$USER_NAME password${NC} is ${GREEN}$USER_PASSWORD${NC}"
 echo -e " - the UCC binary files are installed to ${GREEN}/usr/local/bin${NC}"
 echo -e " - all data and configuration for the masternode is located at ${GREEN}$DATA_DIR${NC} and the folders within"
 echo -e " - the UCC configuration file is located at ${GREEN}$DATA_DIR/$CONFIG_FILE${NC}"
 echo -e " - the masternode privkey is ${GREEN}$PRIV_KEY${NC}"
 echo
 echo -e "You can manage your UCC service from your SSH cmdline with the following commands:"
 echo -e " - ${GREEN}systemctl start $USER_NAME.service${NC} to start the service."
 echo -e " - ${GREEN}systemctl stop $USER_NAME.service${NC} to stop the service."
 echo -e " - ${GREEN}systemctl status $USER_NAME.service${NC} to get the status of the service."
 echo
 echo -e "The installed service is set to:"
 echo -e " - auto start when your VPS is rebooted."
 echo -e " - rotate your ${GREEN}$LOG_FILE${NC} file once per week and keep the last 4 weeks of logs."
 echo
 echo -e "The daemon is installed to run as a service, so the ${GREEN}${DAEMON_BINARY} -daemon${NC} and ${GREEN}${CLI_BINARY} stop${NC}"
 echo -e "commands do not need to be used. You should use the ${GREEN}servicectl${NC} commands listed above instead."
 echo
 echo -e "You can find the masternode status when logged in as $USER_NAME using the command below:"
 echo -e " - ${GREEN}${CLI_BINARY} getinfo${NC} to retrieve your nodes status and information"
 echo
 echo -e "  if you are not logged in as $USER_NAME then you can run ${YELLOW}su - $USER_NAME${NC} to switch to that user before"
 echo -e "  running the ${GREEN}getinfo${NC} command."
 echo -e "  NOTE: the deamon must be running first before trying this command. See notes above on service commands usage."
 echo 
 echo -e "You can run ${GREEN}htop${NC} if you want to verify the UCC service is running or to monitor your server."
 if [[ $SSH_PORTNUMBER -ne $DEFAULT_SSH_PORT ]]; then
 echo
 echo -e " ATTENTION: you have changed your SSH port, make sure you modify your SSH client to use port $SSH_PORTNUMBER so you can login."
 fi
 echo 
 echo -e "================================================================================================================================"
 echo
}

function cleanup()
{
  echo -e "${GREEN}Cleaning up the temporary folders ...${NC}"
  rm -rfv "$TMP_FOLDER"
}

function setup_node() 
{
  ask_user
  ask_ssh_port
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  add_daemon_service
  add_log_truncate
  show_output
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
echo -e "This script will automate the installation of your UCC coin masternode and server configuration by"
echo -e "performing the following steps:"
echo
echo -e " - Create a swap file if VPS is < 2GB RAM for better performance"
echo -e " - Prepare your system with the required dependencies"
echo -e " - Obtain the latest UCC masternode files from the UCC GitHub repository"
echo -e " - Create a user and password to run the UCC masternode service"
echo -e " - Install the UCC masternode service"
echo -e " - Update your system with a non-standard SSH port (optional)"
echo -e " - Add DDoS protection using fail2ban"
echo -e " - Update the system firewall to only allow; SSH, the masternode ports and outgoing connections"
echo -e " - Manage your log files using the logrotate utility"
echo
echo -e "The script will output ${YELLOW}questions${NC}, ${GREEN}information${NC} and ${RED}errors${NC}"
echo -e "When finished the script will show a summary of what has been done."
echo
echo -e "Script created by click2install and adopted by fly"
echo -e " - GitHub: https://github.com/UCCNetwork/installscript/"
echo -e " - Discord: click2install#9625"
echo -e " - UCC Donation: UZVPzBSEYeFKCpchjBGr72tC3SMpgvNWSe"
echo 
echo -e "========================================================================================================="
echo
read -e -p "$(echo -e $YELLOW Do you want to continue? [Y/N] $NC)" CHOICE

if [[ ("$CHOICE" == "n" || "$CHOICE" == "N") ]]; then
  exit 1;
fi

checks

if [[ "$NEW_NODE" == "new" ]]; then
  prepare_system
  deploy_binary
  setup_node
  cleanup
fi
