#!/bin/bash

if [ $HOSTNAME == "host" ] || [ $HOSTNAME == "host2" ]; then
	host_user="user"
else
	host_user="user1"
fi

asset_tag="$1"
tmux new -s "kernel_update" -d
tmux send-keys -t "kernel_update" "bash -x kernel_update.sh "$asset_tag" "$host_user"" C-m
tmux attach -t "kernel_update" -d