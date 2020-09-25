#!/bin/bash
###############################################################
#provisioning script at /bin/provision.sh for MDrecert process#
###############################################################
# eMax 02/2020												  #	
# Automation script to turn a base 18.04 server image into    #
# a Live ISO to repair MD devices   						  #
# v1.0								                          #
###############################################################

username="strivr"
pass="strivr"

### URLs for files that must be downloaded, hosted on STRIVR azure dev ops repo
sudo rm -rf /root/warehouse
sudo rm -rf /warehouse
sudo rm -rf warehouse
git clone --single-branch --branch Max 
sudo cp -r warehouse /root/
wait 
PinguyBuilder="/root/warehouse/MDTool/pinguybuilder_5.2-1_all.deb"
PinguyGrubFile="/root/warehouse/MDTool/grub.cfg"
FirstRun="/root/warehouse/MDTool/FirstRun.sh"
RcLocalService="/root/warehouse/MDTool/rc-local.service"
ProfilePath="/etc/systemd/system/getty@tty1.service.d/"
ConfFile="/etc/systemd/system/getty@tty1.service.d/override.conf"
CryptFile="/root/warehouse/MDTool/strivr-dev-test-4b5e0b710ebf.json"
Recert="/root/warehouse/MDTool/MDrecert.sh"
RecertCFG="/root/warehouse/MDTool/MDrecert.cfg"

### check to make sure not provisioned yet
File=$(ls /bin |grep -c "complete.lock")

### 18.04 does not ship with rc.local enabled, lets set it up
RClocal(){
	sudo cp ${RcLocalService} /etc/systemd/system/rc-local.service
	
	sudo printf '%s\n' '#!/bin/bash' 'sudo bash -x /bin/provision.sh Main' 'exit 0' | sudo tee -a /etc/rc.local
	sudo chmod +x /etc/rc.local
	sudo systemctl enable rc-local
}

### install script dependancies 
Dependancies(){

	sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -qq 
	#wait
	
	sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 
	#wait 
	
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y aria2
	#wait
	
	sudo add-apt-repository ppa:apt-fast/stable -y
	sudo apt-get update
	#wait
	
	###cant config ap fast w/ no interractions without these
	echo debconf apt-fast/maxdownloads string 16 | sudo debconf-set-selections
	echo debconf apt-fast/dlflag boolean true | sudo debconf-set-selections
	echo debconf apt-fast/aptmanager string apt-get | sudo debconf-set-selections
	sudo apt-get install -y apt-fast
	
	sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install
	#wait
	
	#sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y ubuntu-desktop 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y memtester 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y mmc-utils 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y nvme-cli 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install -y sysvbanner 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast download smartmontools
	sudo dpkg -i smart*
	sudo DEBIAN_FRONTEND=noninteractive snap install network-manager 
	#wait
	sudo DEBIAN_FRONTEND=noninteractive snap set network-manager ethernet.enabled=true
}

### create the new user ###
CreateUser(){
	
	sudo useradd -m "${username}"
	echo ''$username':'$pass'' | sudo chpasswd
	usermod -aG sudo "${username}"
	sleep 5
	sudo mkdir ${ProfilePath}
	sudo touch ${ConfFile}
	sudo echo "[Service]" >> ${ConfFile}
	sudo echo "ExecStart=" >> ${ConfFile}
	sudo echo "ExecStart=-/sbin/agetty -o '-p -f strivr' -a strivr --noclear %I $TERM" >> ${ConfFile}
	#sudo echo "ExecStart=-/sbin/agetty --noissue --autologin s %I $TERM" >> ${ConfFile}
	
	### give strivr sudp permission for bash ##
	sudo echo "strivr ALL = NOPASSWD: /bin/bash" >> /etc/sudoers
	
	### launch the troubleshooting script on signin ###
	
	sudo echo "sudo bash -x /home/FirstRun.sh" >> /home/strivr/.profile
}

### download the firstrun script onto the drive and place it ###
FirstRun(){
	sudo cp ${FirstRun} /home/FirstRun.sh
	sleep 10
	ls /home/strivr/
	sleep 10
}

### download PinguyBuilder and install ###
PinguyBuilderInstall(){

	dpkg -i "${PinguyBuilder}"
	sudo DEBIAN_FRONTEND=noninteractive apt-fast -f install -y --fix-missing
}

### attempt to bring up the network adapter w/ network-manager
NetworkUp(){

	sudo snap set network-manager ethernet.enabled=true
	sudo touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
	sudo touch /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
	sudo nmcli dev set enp1s0 managed yes
	sudo systemctl restart NetworkManager
}

### setup google bucket 
GoogleSetUp(){
	sudo echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
	sudo apt-fast install apt-transport-https ca-certificates gnupg -y -qq
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
	sudo DEBIAN_FRONTEND=noninteractive apt-fast update -y -qq
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install google-cloud-sdk -y -qq
}

### install python 3.8
PythonInstall(){

	sudo DEBIAN_FRONTEND=noninteractive sudo apt-fast install zlib1g-dev -y -qq 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install build-essential checkinstall -y -qq 
	#wait
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install libreadline-gplv2-dev libncursesw5-dev libssl-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev -y -qq 
	sudo DEBIAN_FRONTEND=noninteractive apt-fast install libsqlite3-dev
	sudo wget https://www.python.org/ftp/python/3.8.1/Python-3.8.1.tgz -O Python-3.8.1.tgz
	sudo cp Python-3.8.1.tgz /opt/Python-3.8.1.tgz
	sleep 5
	sudo tar xzf /opt/Python-3.8.1.tgz
	sleep 5
	sudo ./Python-3.8.1/configure --enable-optimizations
	#wait
	sudo make altinstall
	#wait
	sudo rm -rf /opt/Python-3.8.1.tgz
	sudo rm -rf Python-3.8.1.tgz
	sleep 10
}

### add some helpful grub options to the live image, download PinguyBuilder grub config
GrubChanges(){

	###add some helpful grub options to the live image
	sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT="nomodeset fsck.mode=force fsck.repair=yes memory_corruption_check=1 vga=768"/' /etc/default/grub
	sudo update-grub
	
	sudo cp ${PinguyGrubFile} /usr/lib/PinguyBuilder/boot/grub/grub.cfg
}


##################
## Main Program ##
##################
Main(){

	if [ "${File}" == "0" ]; then
		
		### create the new user ###
		CreateUser
		###18.04 does not ship with rc.local enabled, lets set it up
		RClocal
		### download the firstrun script onto the drive and place it ###
		FirstRun
		## Install dependancies ###
		Dependancies
		### download PinguyBuilder and install ###
		PinguyBuilderInstall
		### stop the gui from running on startup ###
		sudo systemctl set-default multi-user.target
		###attempt to bring up the network adapter w/ network-manager
		NetworkUp
		###setup google bucket 
		GoogleSetUp
		###install python 3.8
		PythonInstall
		###add some helpful grub options to the live image
		GrubChanges
		###drop the machine and reboot to finish provisioning
		sudo touch /bin/complete.lock
		#wait
		sudo reboot
	
	else 
		
		DeviceModel=$(dmidecode -t1 |grep -ai "product name" |awk '{print $3}')
		if [ "${DeviceModel}" == "VirtualBox" ]; then
			#remove any temp files
			sudo PinguyBuilder clean
		
			DateString=$(date +"%d-%m-%y-%H%M.iso")
			
			#create the iso
			sudo PinguyBuilder backup "${DateString}"
			
			#Authorize the device
			gcloud auth activate-service-account --key-file "${CryptFile}"
		
			#upload the image
			gsutil cp /home/PinguyBuilder/PinguyBuilder/"${DateString}" gs://device-health/Images/"${DateString}"
		fi
		
		#kill the script so it doesnt loop
		sudo rm /bin/provision.sh
		sudo printf '%s\n' '#!/bin/bash' 'exit 0' | sudo tee -a /bin/provision.sh
		
		#delete the files
		sudo rm -rf /root/warehouse
		
		#wait
	fi

}

Main

"$@"