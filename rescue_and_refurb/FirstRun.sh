#!/bin/bash

WifiPass=""
WifiSSID=""
LogFile="/driveDestination/log.txt"

WifiSetupOptions(){

exec 3>&1;
WifiSSID=$(dialog --inputbox "Enter SSID" 0 0 2>&1 1>&3);
exitcode=$?;
exec 3>&-;
echo $result $exitcode;

exec 3>&1;
WifiPass=$(dialog --inputbox "Enter Password" 0 0 2>&1 1>&3);
exitcode=$?;
exec 3>&-;
echo $result $exitcode;

}

#programatically find network adapters
NetworkAdapterTests(){

	declare -a NetworkAdapters
	
	#find number of adapters reported by system
	LSHW=$(lshw -class network) #cache this because its slow af
	NumberOfAdapters=$(grep -ai -c "network" <<< "${LSHW}")
	case "${NumberOfAdapters}" in
		
		0)
			echo "No network adapters found" >> "${LogFile}"
			;;
		
		1)
			echo "Only found 1 network adapter" >> "${LogFile}"
			TestAdapters
			;;
		
		2)
			echo "Found expected number of adapters" >> "${LogFile}"
			TestAdapters
			;;
		
		*)
			echo "Something went horribly wrong, but were gonna test anyway" >> "${LogFile}"
			TestAdapters
			;;
	esac
}

#try to troubleshoot and verify adapter
TestAdapters(){
	echo "TestAdapters" > "${LockFile}"
	declare -a NetworkAdapters
	LSHW="/tmp/lshw.txt"
	LSHWS="/tmp/lshws.txt"
	lshw -class network > "${LSHW}"
	lshw -short |grep -ai "network" > "${LSHWS}"
	
	#find number of adapters reported by system

	
	NumberOfAdapters=$(cat "${LSHWS}" |awk '{print $3}' | grep -ai -c "network")
	
	for (( i = 0; i < "${NumberOfAdapters}"; ++i ))
	do
		Line=$(("${i}" + 1))
		Name=$(cat "${LSHWS}" |grep -ai -m"${Line}" "network" |awk '{print $2}' | tail -n1)
		NetworkAdapters["${i}"]="${Name}"
	done
	
	#check network manager setup
	for k in "${NetworkAdapters[@]}" 
	do
		Result=$(nmcli dev)
		echo "${Result}" >> "${LogFile}"
		
		Device=$(grep -ai "${k}" <<< "${Result}" |awk '{print $1}')
		
		if [ ! -z "${Device}" ]; then
			Type=$(grep -ai "${k}" <<< "${Result}" |awk '{print $2}')
			State=$(grep -ai "${k}" <<< "${Result}" |awk '{print $3}')
			Connection=$(grep -ai "${k}" <<< "${Result}" |awk '{print $4}')
			
			#attempt to bring a ethernet adapter online
			IsWired=$(cat "${LSHWS}" |grep -ai "${k}" |grep -ai -c 'ethernet')
			if [ "${IsWired}" == 1 ]; then
				if [ "${State}" == "unmanaged" ]; then
					sudo snap set network-manager ethernet.enabled=true
					sudo touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
					sudo touch /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
					sudo nmcli dev set ${k} managed yes
					sudo systemctl restart NetworkManager
					sleep 5
				fi
			fi		
			
			#attempt to connect to wifi
			IsWireless=$(cat "${LSHWS}" |grep -ai "${k}" |grep -ai -c 'wireless')
			if [ "${IsWireless}" == 1 ]; then
				if [[ "${State}" == "unavailable" ]] || [[ "${State}" == "disconnected" ]] ; then
					#WifiSetupOptions
					nmcli device wifi connect "${WifiSSID}" password "${WifiPass}" |dialog --progressbox 100 100
				fi
			fi
			
		else
			echo "Device not reported by network manager" >> "${LogFile}"		
		fi
	done
	OnlineCheck
}

#kill if on a virtual machine
Vbox(){
DeviceModel=$(dmidecode -t1 |grep -ai "product name" |awk '{print $3}')
	if [ "${DeviceModel}" == "VirtualBox" ]; then
		echo "Device is a virtual machine, exiting" >> "${LogFile}"
		exit
	else
		DataGrab 
	fi
}

#check if able to get online
OnlineCheck(){

	wget -q --spider http://google.com
	
	if [ $? -eq 0 ]; then
		git clone --single-branch --branch 
		wait 
		MDrecert="/home/strivr/warehouse/MDTool/MDrecert.sh"	
		echo "Device Online, downloading updated scripts" >> "${LogFile}"
		apt-get purge -y openssh-server |dialog --progressbox 100 100
		apt-get install openssh-server |dialog --progressbox 100 100
		bash -x ${MDrecert} RunFull 
	else
		echo "Device Offline, unable to connect to web" >> "${LogFile}"
	fi
}

#pull data from the MD
DataGrab(){

	AssetTag=$(dmidecode -t1 |grep -ai "serial number" |awk '{print $3}')
	
	#drive to get data off of
	mkdir /driveSource
	mkdir /driveDestination
	
	#mount em
	mount /dev/sda2 /driveSource
	mount /dev/sdb2 /driveDestination
	
	mkdir /driveDestination/${AssetTag}
	
	#grab the data
	rsync -ah --progress /driveSource/home/strivr/* /driveDestination/${AssetTag}/strivr/ |dialog --progressbox 100 100
	NetworkAdapterTests
}

Vbox