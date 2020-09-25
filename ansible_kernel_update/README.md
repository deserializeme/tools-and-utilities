#introduction
**~Tool to update kernel on MDs~**
$bash/Ansible

**kernel_update.sh** -- handles host-side environment and launches *main.yml*

**launch_update.sh** -- accepts input and starts a tmux session, runs *kernel_update.sh*, then attaches to the session.

**main.yml** -- playbook

**mds_to_update** -- will be overwritten, generated at runtime.


