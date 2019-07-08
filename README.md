# UCC Masternode Installation Script - Readme

Shell scripts to install and remove a UCC Masternode on a Linux server running Ubuntu 16.04.

## Contents

  - [Installation](#Installation)
  - [How to setup your masternode with this script and a cold wallet on your PC](#how-to-setup-your-masternode-with-this-script-and-a-cold-wallet-on-your-PC)
  - [Multiple master nodes on one server](#multiple-master-nodes-on-one-server)
  - [Running the install script](#running-the-install-script)
  - [Upgrading an existing running node](#upgrading-an-existing-running-node)
  - [Removing a master node](#removing-a-master-node)
  - [Security](#security)
  - [Disclaimer](#disclaimer)



## Installation 

Login as root-user and execute this line, it will download the script and install the node:

```
wget -q https://raw.githubusercontent.com/UCCNetwork/installscript/master/install_ucc_binary.sh && bash install_ucc_binary.sh 
```

**NOTE:** The istall script needs to be run as the root user. You can `su - root` once you login to change to the root user before running the script. See the [Security](#security) section below on how to setup your node so you are not logging in or installing programs into the root users account.

Donations for the creation and maintenance of this script are welcome at:
&nbsp;

UCC: UZVPzBSEYeFKCpchjBGr72tC3SMpgvNWSe

&nbsp;

## How to setup your masternode with this script and a cold wallet on your PC
The script assumes you are running a cold wallet on your local PC and this script will execute on a Ubuntu Linux VPS (server). The steps involved are:

 1. Run this script as the instructions detail below
 2. When you are finished this process you will get some infomration on what has been done as well as some important information you will need for your cold wallet setup
 3. Copy/paste the output of this script into a text file and keep it safe.

You are now ready to configure your local wallet and finish the masternode setup

 1. Make sure you have downloaded the latest wallet from https://github.com/UCCNetwork/ucc/releases
 2. Install the wallet on your local PC
 3. Start the wallet and let if completely synchronize to the network - this will take some time
 4. Make sure you have at least 1000.2 UCC in your wallet (Light Node)
 5. Open your wallet debug console
 6. In the console type: `getnewaddress [address-name]` - e.g. `getnewaddress mn1`
 7. In the console type: `sendtoaddress [output from #6] 1000` for Light Node, `sendtoaddress [output from #6] 3000` for medium Node and `sendtoaddress [output from #6] 5000` for full Node
 8. Wait for the transaction from #7 to be fully confirmed. Look for a tick in the first column in your transactions tab
 9. Once confirmed, type in your console: `masternode outputs`
 10. Open your masternode configuration file from Tools > Open Masternode Configuration File
 11. In your masternodes.conf file add an entry that looks like: `[address-name from #6] [ip:port of your VPS] [privkey from script output] [txid from from #9] [output index from #9]` - 
 12. Your masternodes.conf file entry should look like: `MN-1 127.0.0.2:6110 93HaYBVUCYjEMeeH1Y4sBGLALQZE1Yc1K64xiqgX37tGBDQL8Xg 2bcd3c84c84f87eaa86e4e56834c92927a07f9e18718810b92e0d0324456a67c 0`
 13. Save and close your masternodes.conf file
 14. Close your wallet and restart the wallet
 15. Go to Masternode Tab and right click on the Node, select START.
 16. Your node should now be running successfully.

&nbsp;


## Multiple master nodes on one server
The script does not support installing multiple masternodes on the same host.

&nbsp;


## Running the install script
When you run the `install-ucc.sh` script it will tell you what it will do on your system. Once completed there is a summary of the information you need to be aware of regarding your node setup which you can copy/paste to your local PC.

If you want to run the script before setting up the node in your cold wallet the script will generate a priv key for you to use, otherwise you can supply the privkey during the script execution.

&nbsp;


## Upgrading an existing running node

If you are upgrading an existing node that was installed using the install script above, you can perform these steps to easily update the node without re-sending your UCC collateral.

 1. Run the update script
 2. Start your node from your local PC wallet as usual

```
wget -q https://raw.githubusercontent.com/UCCNetwork/installscript/master/update-ucc.sh && bash update-ucc.sh
```

&nbsp;

## Removing a master node
If you have used the `install-ucc.sh` script to install your masternode and you want to remove it. You can run `remove-ucc.sh` to clean your server of all files and folders that the installation script created.

For removal, run the following commands from your server:

```
wget -q https://raw.githubusercontent.com/UCCNetwork/installscript/master/remove-ucc.sh  
bash remove-ucc.sh
rm -f remove-ucc.sh
```

**NOTE:** The remove script needs to be run as the root user. You can `su - root` once you login to change to the root user before running the script.

#### IMPORTANT NOTE:
The removal script will permanently delete files. If you have coins in your VPS wallet, i.e., you are not running a local PC wallet that stores your coins, then you should backup the wallet.dat file on the VPS to your local PC before running the `remove-ucc` script. 


&nbsp;

## Security
The script allows for a custom SSH port to be specified as well as setting up the required firewall rules to only allow inbound SSH and node communications, whilst blocking all other inbound ports and all outbound ports.

The [fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page) package is also used to mitigate DDoS attempts on your server.

Despite this script needing to run as `root` you should secure your Ubuntu server as normal with the following precautions:

 - disable password authentication
 - disable root login
 - enable SSH certificate login only

If the above precautions are taken you will need to `su root` before running the script.

If you need assistance in the server setup there is a guide available here - https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-16-04.

&nbsp;

## Disclaimer
Whilst effort has been put into maintaining and testing this script, it will automatically modify settings on your Ubuntu server - use at your own risk. By downloading this script you are accepting all responsibility for any actions it performs on your server.

&nbsp;
