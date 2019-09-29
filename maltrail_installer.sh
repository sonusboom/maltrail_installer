#!/bin/bash
#
# Script Name: MalTrail Installer
# Created By: SonusBoom
# Original Date: 9/26/2019
# 
# 
# This script is designed to quickly install MalTrail on Ubuntu for testing
# or production purposes. Please see https://github.com/stamparm/maltrail
# for additional information regarding the software.
#
# The following actions are performed:
# 
# - Updates system
# - Installs supporting package(s)
# - Installs latest version of Maltrail
# - Sets recommended cron jobs
# - Allows you to change the Admin password
#
#
# Comments that contain "***" are sections of code that came from
# github.com/da667 AutoMISP script. Please check out his GitHub
# page.

# ***Make the script look extra expensive with some nice outputs***

function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

# ***Function to perform error checking.***

function error_check () {

if [ $? -eq 0 ]; then
	print_good "$1 successfully completed."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

# ***Check for root user status***

print_status "Checking for root..."
if [ $(whoami) != "root" ]; then
	print_error "Root check failed...please execute script with sudo..."
	exit 1
else
	print_good "Root check successful..."
fi


# ***Redirect certain processes to an install log***

logfile=/var/log/maltrail_installer.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe


function install_maltrail () {
	
	# Perform system update
	echo " "
	print_status "Updating $(lsb_release -sd)...(this may take awhile)..."
	sudo apt-get update &>> $logfile && sudo apt-get upgrade -y &>> $logfile
	echo " "
	error_check "Update of $(lsb_release -sd)..."

	# Install Dependency packages to support MalTrail
	echo " "
	print_status "Installing Python-pcapy to support Maltrail..."
	sudo apt-get install python-pcapy -y &>> $logfile
	echo " "
	error_check "Installation of python-pcapy..."

	# Download and install Maltrail
	echo " "
	print_status "Installing MalTrail..."
	cd /tmp
	git clone https://github.com/stamparm/maltrail.git &>> $logfile
	sudo mv /tmp/maltrail /opt
	sudo chown -R $USER:$USER /opt/maltrail
	sudo mkdir -p /var/log/maltrail
	sudo mkdir -p /etc/maltrail
	sudo cp /opt/maltrail/maltrail.conf /etc/maltrail
	echo " "
	error_check "Installation of Maltrail..."
	
	# Set MalTrail cronjobs
	echo " "
	print_status "Installing MalTrail cronjobs..."
	cat > maltrailjobs.txt <<-EOF
	# autostart server & periodic update
	*/5 * * * * if [ -n "\$(ps -ef | grep -v grep | grep 'server.py')" ]; then : ; else python /opt/maltrail/server.py -c /etc/maltrail/maltrail.conf; fi
	0 1 * * * cd /opt/maltrail && git pull
	#
	# autostart sensor & periodic restart
	*/1 * * * * if [ -n "\$(ps -ef | grep -v grep | grep 'sensor.py')" ]; then : ; else python /opt/maltrail/sensor.py -c /etc/maltrail/maltrail.conf; fi
	2 1 * * * /usr/bin/pkill -f maltrail
	EOF
	sleep 2
	echo " "
	sudo crontab maltrailjobs.txt &>> $logfile
	error_check "Installation of Maltrail cronjobs..."
	echo " "
	sleep 2
	clear
	admin_password
}
	
function admin_password () {
	
	# Change default admin password or leave alone
	read -p "Would you like to update the admin password? (Y/N): " -n 1 -r
	echo " "
	if [[  $REPLY =~ ^[Yy]$ ]]; then
		echo " "
		read -p "Enter new admin account password: " passwd
	
		adminpasswd=$(echo -n "${passwd}" | sha256sum |awk '{print $1}') 
	
		sed -i "s|admin:.*|admin:${adminpasswd}:0:|g" /etc/maltrail/maltrail.conf 
		echo " "
		error_check "Admin password update..."
		echo " "
		read -p "Press any key to continue..."
	
	else
		echo " "
		print_status "Admin account password has been left to previous or default of changeme!..."
		echo " "
		read -p "Press any key to continue..."
	fi	
}

# Check to see if MalTrail is already installed and install it

if [[ -d /opt/maltrail ]]; then
	clear
	echo " "
	print_status "It appears that MalTrail is already installed..."
	echo " "
	admin_password
else
	read -p "Would you like to install MalTrail? (Y/N): " -n 1 -r
	if [[  $REPLY =~ ^[Yy]$ ]]; then
	echo " "
	print_status "Preparing to install MalTrail..."
	sleep 2
	clear
	install_maltrail
	fi
fi
