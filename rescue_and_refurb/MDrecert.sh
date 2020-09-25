#!/bin/bash

################################################################
# Automated data gathering and troubleshooting script
# eMax 2019/20
################################################################
#                       Dependancies
################################################################
#Grub Options = "nomodeset fsck.mode=force fsck.repair=yes memory_corruption_check=1"
#/etc/suroers add strivr ALL = NOPASSWD: /home/t
#sudo systemctl set-default multi-user.target
#sudo tune2fs -c 1 /dev/sda2
#openssh-server
#dialog
#memtester
#mmc-utils
#network-manager
#nvme-cli
#smartmontools
#sysvbanner
#snap install network-manager
#apt-fast
#aria2
#google cloud SDK
#Python 3.8
#set up rc.local and systemd service
#change /home/strivr/.profile
#echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list



################################################################
#TODO -> 
#completion progress checks, 
#JSON integration,
#data transfer
################################################################


################################################################
# Global Variables 
################################################################
declare -a DiskNameArray
AssetTag=$(dmidecode -t1 |grep -ai "serial number" |awk '{print $3}')
sudo mkdir /driveDestination/${AssetTag}/




################################################################
#configurable variables - handeled in setupoptions functions
################################################################
git clone --single-branch --branch
wait 
MDrecertCFG="/home/strivr/warehouse/MDTool/MDrecert.cfg"

WifiPass=$(cat ${MDrecertCFG} |head -2 |tail -1 |awk '{print $2}')
echo $WifiPass
WifiSSID=$(cat ${MDrecertCFG} |head -1 |awk '{print $2,$3}')
echo $WifiSSID
MemTestSize=$(cat ${MDrecertCFG} |head -3 |tail -1 |awk '{print $2}')
echo $MemTestSize
MemTestPasses=$(cat ${MDrecertCFG} |head -4 |tail -1 |awk '{print $2}')
echo $MemTestPasses
LogFile="log.txt"
LockFile="/tmp/lock"

################################################################
#   Setup Options
################################################################

MemtestSetupOptions(){

################
# Memtest Size
################
cmd=(dialog --keep-tite --menu "Select Memtester memory size:" 22 76 16)

options=(1 "256"
         2 "512"
         3 "1024"
         4 "2048")

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
    case $choice in
        1)
            MemTestSize="256"
            ;;
        2)
            MemTestSize="512"
            ;;
        3)
            MemTestSize="1024"
            ;;
        4)
            MemTestSize="2048"
            ;;
    esac
done

################
# Memtest Passes
################
cmd=(dialog --keep-tite --menu "Select Memtester passes to perform:" 22 76 16)

options=(1 "1"
         2 "2"
         3 "4"
         4 "8")

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
    case $choice in
        1)
            MemTestPasses="1"
            ;;
        2)
            MemTestPasses="2"
            ;;
        3)
            MemTestPasses="4"
            ;;
        4)
            MemTestPasses="8"
            ;;
    esac
done

}

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

################################################################
#   Hardware Tests
################################################################

#gather hardware specs and identifiers
DeviceInfo(){

Path="/driveDestination/${AssetTag}/${AssetTag}_DeviceInfo.json" 
	
	echo "DeviceInfo" >> "${LockFile}"
	echo "Gathering system Information" >> "${LogFile}"
	
	AssetTag=$(dmidecode -t1 |grep -ai "serial number" |awk '{print $3}')
	if [ -z "${AssetTag}" ]; then
		echo "No Asset tag found" >> "${LogFile}"
	fi

    
	DeviceModel=$(dmidecode -t1 |grep -ai "product name" |awk '{print $3}')
	if [ -z "${DeviceModel}" ]; then
		echo "Could not get device model" >> "${LogFile}"
	fi

	BiosVersion=$(dmidecode -t0 |grep -ai "Version" |awk '{print $2}')
	if [ -z "${AssetTag}" ]; then
		echo "Could not find Bios version" >> "${LogFile}"
	fi
    
    
	BiosDate=$(dmidecode -t0 |grep -ai "Release" |awk '{print $3}')
	if [ -z "${BiosDate}" ]; then
		echo "Could not get Bios date" >> "${LogFile}"
	fi
	
	echo '{"Device Info":{"Asset Tag":"'${AssetTag}'","Device Model":"'${DeviceModel}'","BIOS Revision":"'${BiosVersion}'","BIOS Date":"'${BiosDate}'"}}' >> ${Path}
	
}

#drive method update
DriveTesting(){

echo "DriveTesting" >> "${LockFile}"
declare -a DiskNameArray
Path="/driveDestination/${AssetTag}/${AssetTag}_DriveTesting.json"

echo "{" >> ${Path}


NumberOfDisks=$(sudo fdisk -l |grep -c 'Disk /dev/sd*')
for (( i = 0; i < "${NumberOfDisks}"; ++i ))
	do
	Line=$(("${i}" + 1))
	Name=$(fdisk -l |grep -ai -m$Line 'Disk /dev/sd*' |awk '{print $2}' |sed 's|[:,]||g' | tail -n1)
	echo "Found Drive ${Name}"
	DiskNameArray["${i}"]="${Name}"
done

	for (( i = 0; i < "${NumberOfDisks}"; ++i ))
	do
	
	#test drive features
		NVME=$(nvme list | grep -ai -c "${DiskNameArray[$i]}")
		if [ "${NVME}" != 0 ]; then
			NvmeData=$(nvme smart-log "${DiskNameArray[$i]}")
			echo "${NvmeData}" >> "${LogFile}"
		fi
	
		EMMC= $(mmc extcsd read "${DiskNameArray[$i]}" 2>/tmp/mmcCheck)
		EMMCCheck=$(cat /tmp/mmcCheck |grep -ai -c 'Could not read')
		if [ "${EMMCCheck}" == 0 ]; then
			EmmcData=$(mmc extcsd read "${DiskNameArray[$i]}")
			echo "${EmmcData}" >> "${LogFile}"
		fi
	
		SMART=$(smartctl -a "${DiskNameArray[$i]}" |grep -ai "smart support is:" |grep -ai -c "Enabled")
		if [ "${SMART}" -gt 0 ]; then
			echo "SMART enabled Device" >> "${LogFile}"
			smartctl -t short "${DiskNameArray[$i]}" |dialog --progressbox 100 100
			
			#short smartctl test (timed)
			sleep 90
			
			#if everything is working, returns 0
			TestResults=$(smartctl --capabilities "${DiskNameArray[$i]}" |grep -ai "Self-test execution status" |awk '{print $5}' |sed 's|[),]||g')
			AllData=$(smartctl -a "${DiskNameArray[$i]}")
			echo "${TestResults}" >> "${LogFile}"
			echo "${AllData}" >> "${LogFile}"
		fi
		
		
		declare -a PartNameArray

		NumberOfParts=$(fdisk -l ${DiskNameArray[$i]} |grep -ai 'Device' -A 5 |grep -c '/dev/sd*')
	
	#build the array of partition names
			for (( j = 0; j < "${NumberOfParts}"; ++j ))
			do
				Line=$(("${j}" + 1))
				Name=$(fdisk -l ${DiskNameArray[$i]} |grep -ai 'Device' -A "${Line}" |grep -ai '/dev/sd*' |tail -1 |awk '{print $1}')
				Count=$(printf '%s\n' "${PartNameArray[@]}" |grep -c ${Name})
				PartNameArray["${j}"]="${Name}"
			done
			
			echo '"'${DiskNameArray[$i]}'": [{"Drive Name": "'${DiskNameArray[$i]}'","SMART featues": "'${AllData}'","EMMC featues": "'${EmmcData}'","NVME Features": "'${NvmeData}'","Number of Partitions": "'${NumberOfParts}'",' >> ${Path}
				
	#loop over array to pull partition specific information
			counter=0
			
			for k in "${PartNameArray[@]}" 
			do
				let counter+=1

				Usage=$(df -H "${k}" |awk '{print $5}' |tail -1)
				FileSystem=$(df -H "${k}" |awk '{print $1}' |tail -1)
				Size=$(df -H "${k}" |awk '{print $2}' |tail -1)
				Used=$(df -H "${k}" |awk '{print $3}' |tail -1)
				Avail=$(df -H "${k}" |awk '{print $4}' |tail -1)
				FSCK=$(fsck -yf ${k})
				Count=$(printf '%s\n' "${PartNameArray[@]}" |grep -c '/dev/sd*')
				if [ "${counter}" == "${Count}" ]; then
					if [ "$(( ${i} + 1 ))" != "${NumberOfDisks}" ]; then
						echo '"'${k}'": {"Volume Size": "'${Size}'","Space Used": "'${Used}'","Space Available": "'${Avail}'","Partition Usage": "'${Usage}'","File System": "'${FileSystem}'","Partition FSCK": "'${FSCK}'"}}],' >> ${Path}
					else
						echo '"'${k}'": {"Volume Size": "'${Size}'","Space Used": "'${Used}'","Space Available": "'${Avail}'","Partition Usage": "'${Usage}'","File System": "'${FileSystem}'","Partition FSCK": "'${FSCK}'"}}]' >> ${Path}
					fi
				else
					echo '"'${k}'": {"Volume Size": "'${Size}'","Space Used": "'${Used}'","Space Available": "'${Avail}'","Partition Usage": "'${Usage}'","File System": "'${FileSystem}'","Partition FSCK": "'${FSCK}'"}],' >> ${Path}
				fi

			done
			
		unset PartNameArray
		
	done
	
echo "}" >> ${Path}
}

#find number of drives attached to system and stash em in memory
BuildDriveArray(){
	NumberOfDisks=$(fdisk -l |grep -c 'Disk /dev/sd*')
	
	if [ "${NumberOfDisks}" -eq 0 ]; then
		echo "No drives found" >> "${LogFile}"
		
	else

		for (( i = 0; i < "${NumberOfDisks}"; ++i ))
		do
			Line=$(("${i}" + 1))
			Name=$(fdisk -l |grep -ai -m$Line 'Disk /dev' |awk '{print $2}' |sed 's|[:,]||g' | tail -n1)
			echo "Found Drive ${Name}" >> "${LogFile}"
			DiskNameArray["${i}"]="${Name}"
		done
	
	fi
}

#check if drives are NVME, EMMC etc...
DriveTypeCheck(){

	for (( i = 0; i < "${NumberOfDisks}"; ++i ))
	do
		NVME=$(nvme list | grep -ai -c "${DiskNameArray[$i]}")
		if [ "${NVME}" != 0 ]; then
			echo "Found NVME Drive" >> "${LogFile}"
			NvmeTests "${DiskNameArray[$i]}"
		fi
	
		EMMC= $(mmc extcsd read "${DiskNameArray[$i]}" 2>/tmp/mmcCheck)
		EMMCCheck=$(cat /tmp/mmcCheck |grep -ai -c 'Could not read')
		if [ "${EMMCCheck}" == 0 ]; then
			echo "Found EMMC Drive" >> "${LogFile}"
			EmmcTests "${DiskNameArray[$i]}"
		fi
	
		SMART=$(smartctl -a "${DiskNameArray[$i]}" |grep -ai "smart support is:" |grep -ai -c "Enabled")
		if [ "${SMART}" -gt 0 ]; then
			echo "Found SMART Drive" >> "${LogFile}"
			SmartTests "${DiskNameArray[$i]}"
		fi
	
	done
}

#takes 1 param /dev/sdX format
NvmeTests(){
	echo "NVME Device" >> "${LogFile}"
	NvmeData=$(nvme smart-log "${1}")
	echo "${NvmeData}" >> "${LogFile}"
}

#takes 1 param /dev/sdX format
EmmcTests(){
	echo "EMMC Device" >> "${LogFile}"
	EmmcData=$(mmc extcsd read "${1}")
	echo "${EmmcData}" >> "${LogFile}"
}

#takes 1 param /dev/sdX format
SmartTests(){
	echo "SMART enabled Device" >> "${LogFile}"
	smartctl -t short "${1}" |dialog --progressbox 100 100
	
	#short smartctl test (timed)
	sleep 90
	
	#if everything is working, returns 0
	TestResults=$(smartctl --capabilities "${1}" |grep -ai "Self-test execution status" |awk '{print $5}' |sed 's|[),]||g')
	AllData=$(smartctl -a "${1}")
	echo "${TestResults}" >> "${LogFile}"
	echo "${AllData}" >> "${LogFile}"
	
}

#for each drive, find partitions and run tests against them 
PartitionTest(){
	
	for (( i = 0; i < "${NumberOfDisks}"; ++i ))
	do
		declare -a PartNameArray

		NumberOfParts=$(df -a |grep -c ${DiskNameArray[$i]})
		
		#only check drives with more than 1 partition
		if [ "${NumberOfParts}" == "1" ]; then
		
			#build the array of partition names
			for (( j = 0; j < "${NumberOfParts}"; ++j ))
			do
				Line=$(("${j}" + 1))
				Name=$(df -a |grep -ai -m"${Line}" '/dev/sd' | awk '{print $1}' | tail -n1)
				Count=$(printf '%s\n' "${PartNameArray[@]}" |grep -c ${Name})
				
				if [ "${Count}" != "1" ]; then
					echo "Found Partition Named ${Name} on drive ${DiskNameArray[$i]}" >> "${LogFile}"
					PartNameArray["${j}"]="${Name}"
				else
					echo "duplicate"
				fi
			done
			
			#loop over array to pull partition specific information
			for k in "${PartNameArray[@]}" 
			do
				Usage=$(df -a |grep ${k} |awk '{print $5}')
				FSCK=$(fsck -yf ${k})
				echo "Partition ${k} on drive ${DiskNameArray[$i]} stats:" >> "${LogFile}"
				echo "FSCK:" >> "${LogFile}"
				echo "${FSCK}" >> "${LogFile}"
				echo "Usage:" >> "${LogFile}"
				echo "${Usage}" >> "${LogFile}"
			done
		fi
	done
}

#programatically find network adapters
NetworkAdapterTests(){

	declare -a NetworkAdapters
	
	#find number of adapters reported by system
	LSHW=$(lshw -class network) #cache this because its slow af
	NumberOfAdapters=$(grep -ai -c "logical" <<< "${LSHW}")
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
	
	Path="/driveDestination/${AssetTag}/${AssetTag}_TestAdapters.json"
	
	echo '{"Network Adapters": {' >> ${Path}
	
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
	
	
	
	NumberOfAdapters=$(cat "${LSHWS}" |awk '{print $3}' | grep -ai -c "network")
	
	for (( i = 0; i < "${NumberOfAdapters}"; ++i ))
	do
		Line=$(("${i}" + 1))
		Name=$(cat "${LSHWS}" |grep -ai -m"${Line}" "network" |awk '{print $2}' | tail -n1)
		Result=$(nmcli dev)
		Type=$(grep -ai "${Name}" <<< "${Result}" |awk '{print $2}')
		State=$(grep -ai "${Name}" <<< "${Result}" |awk '{print $3}')
		Connection=$(grep -ai "${Name}" <<< "${Result}" |awk '{print $4}')
		
		if [ ${Line} -ne ${NumberOfAdapters} ]; then
			echo '"'${Name}'": {"Status": "'${Connection}'","State": "'${State}'"},' >> ${Path}
		else
			echo '"'${Name}'": {"Status": "'${Connection}'","State": "'${State}'"}}' >> ${Path}
		fi
		
	done
	
	
	echo '}' >> ${Path}
}

#run a memory test 
MemoryTest(){

	echo "MemoryTest" > "${LockFile}"
	#MemtestSetupOptions
	memtester "${MemTestSize}" "${MemTestPasses}" |dialog --progressbox 100 100
	wait
	sleep 10
}

#excludes virtual machines
Vbox(){
echo "Vbox" > "${LockFile}"
DeviceModel=$(dmidecode -t1 |grep -ai "product name" |awk '{print $3}')
	if [ "${DeviceModel}" == "VirtualBox" ]; then
		echo "Device is a virtual machine, quitting" >> "${LogFile}"
		exit
	fi
}

#final step
EndProgram(){
	echo "EndProgram" > "${LockFile}"
	banner COMPLETED
}

#check file system for errors
FileSystemCheck(){
	echo "FileSystemCheck" > "${LockFile}"
	umount /dev/sda2
	fsck -yf /dev/sda2 |dialog --progressbox 100 100
}

#state monitoring of program
ProgressCheck(){

Status=$(cat "${LockFile}")

	case "${Status}" in
		"Cleanup")
			Cleanup
			wait
			;;
		"Vbox")
			Vbox
			wait
			;;
		"ProgressCheck")
			echo "skip"
			;;
		"DeviceInfo")
			DeviceInfo
			wait
			;;
		"FileSystemCheck")
			FileSystemCheck
			wait
			;;
		"DriveTesting")
			DriveTesting
			wait
			;;
		"NetworkAdapterTests")
			NetworkAdapterTests
			wait
			;;
		"MemoryTest")
			MemoryTest
			wait
			;;
		"EndProgram")
			EndProgram
			wait
			;;
		*)
           echo $"unknown state"
           ;;
	esac
}

#clean up log files
Cleanup(){
	sudo rm ${LogFile}
    sudo rm ${LockFile}
}

#runs the full program
RunFull(){

	echo "Cleanup" > ${LockFile}
	ProgressCheck
	echo "ProgressCheck" > ${LockFile}
	ProgressCheck
	echo "Vbox" > ${LockFile}
	ProgressCheck
	echo "DeviceInfo" > ${LockFile}
	ProgressCheck
	echo "FileSystemCheck" > ${LockFile}
	ProgressCheck
	#############################
	#turn off outdated functions#
	#############################
	#echo "BuildDriveArray"		#
	#echo "DriveTypeCheck"      #
	#echo "PartitionTest"       #
	#############################
	echo "DriveTesting" > ${LockFile}
	ProgressCheck
	echo "NetworkAdapterTests" > ${LockFile}
	ProgressCheck
	echo "MemoryTest" > ${LockFile}
	ProgressCheck
	echo "EndProgram" > ${LockFile}
	ProgressCheck
	echo "ProgressCheck" > ${LockFile}

}




"$@"





