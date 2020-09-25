#!/bin/bash
echo "waiting for tmux session to attach..."
sleep 3

asset_tag=$1
host_user=$2
sql_user="mdhost"
dbname="DeviceService"
table="device"
type="MD"
host="localhost"
asset_tag=$1
command="SELECT port from "$table" where type='"$type"' and assettag='"$asset_tag"'"
warnAboutCron=false

#check if we are th right user
#walmart automations are still under eric's name
if [ "$(whoami)" != "${host_user}" ]; then
        echo 'Script must be run as user: '${host_user}''
		exit 255
fi

# Set up a trap to report if we failed before turning cron back on
function cleanup
{
    if [[ "$warnAboutCron" == "true" ]]; then
        echo
        echo
        echo "WARNING: Cron is still disabled on $mdHost !! (run 'sudo cron start' to enable)"
        echo
        warnAboutCron=false
    fi
}

trap cleanup EXIT # Trap on normal exit
trap cleanup ERR # Trap on failures causing exit due to set -e
trap cleanup SIGINT # Trap on ctrl-c

#get the port based on asset tag
PORT=$(psql -t -q --host="$host" --user="$sql_user" --dbname="$dbname" --command="$command")
clean_port=$(sed 's/ //g' <<< "$PORT")

#test connectivity
sudo ssh -o StrictHostKeyChecking=no -p $clean_port user@localhost -q exit
return_code=$?

if [ "${return_code}"  != "0" ]; then
	echo "unable to connect, ensure it is online then run again"
	exit 255
fi

# Stop cron to prevent any automatic update runs, and then stop any update run
# that might be in progress
sudo systemctl stop cron
warnAboutCron=true

#check for running script instances
pids=$(ps aux |grep "update.sh")

#count pids
count=$(grep -c "update.sh" <<< "$pids")
declare -a pids_to_kill

#add to a list
for ((i = 0 ; i < ${count} ; i++)); do
  ((j=i+1))
  pid=$(grep "update.sh" <<< "$pids" |awk '{print $2}' |head -"$j" |tail -1)
  pids_to_kill["$i"]="$pid"
done

#kill em all
for i in "${pids_to_kill[@]}"
do
	sudo kill -9 '${i}'
done

#close other tmux sessions
tmux kill-session -a

#generate the inventory file
sudo touch /tmp/mds_to_update
sudo chmod 777 /tmp/mds_to_update
string=$(echo "'${asset_tag}' ansible_port='${clean_port}' ansible_host=localhost")
sudo echo $string > /tmp/mds_to_update 
cat /tmp/mds_to_update 
sleep 5

#run ansible script (currently just checking)
sudo ansible-playbook --verbose --inventory "/tmp/mds_to_update"  \
--ssh-extra-args='-o StrictHostKeyChecking=no' \
--private-key=/home/user/.ssh/id_rsa \
--timeout=60 \
main.yml

# Start cron again
sudo systemctl start cron
warnAboutCron=false

#clean up
sudo rm /tmp/mds_to_update

#that's all folx <3, thanks for playing
sudo -u $host_user tmux kill-server || true

