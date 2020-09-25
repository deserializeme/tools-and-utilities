# Introduction 
**MDTool is a set of automation scripts designed to collect detailed hardware information, conduct recertification testing and troubleshooting and capture data with as little human interraction as possible**

**Provision.sh** - will convert a base ubuntu image into the MDtool environment and create a Live Image of the system.  

**FirstRun.sh** - Handles getting the device online after boot if possible, and updates the process to latest version.  

**MDrecert.sh** - Troubleshooting script responsible for diagnosis, documentation, and repair of MD devices.  

**MDrecert.cfg** - configuration settings for MDrecert.sh  

**rc-local.service** - you should know what rc-local does  
 
**grub.cfg** - custom grub config for the Live ISO

# Building the Environment Manually
1.	install Ubuntu 18.04 server on a virtual machine or physical box (also compatible with Vagrant)
2.	Make sure VM has access to network/internet
3.	move provision.sh to /bin/provision.sh
4.	Execute script as root
5.  Retreive the created .iso file from the machine or from google bucket
6.  Use Rufus/Unetbootin or other live usb creation tool that supports a casper OS partition.
7.  Boot from created USB stick.

# Building the Environment Automatically
1. Using a tool like docker or Vagrant, import the ubuntu base image of your choice, and run provision.sh against the instance to configure 
2. Virtual machine will upload created ISO


# Known Issues
1. Live ISO grub options not correct in built image (sometimes/wip)
2. Virtual Machine reboot flag from provision.sh f=does not always work (wip)
3. will be moving to ansible when i can


Good Luck and Have Fun!