#!/bin/bash
# first time setup

mkdir -p /root/.ssh
cd /root/.ssh

if ! [ -e ssh_host_ed25519_key.pub ]
then
	echo "Error: ssh_host_ed25519_key.pub not found. Make sure it is located at '/root/.ssh/ssh_host_ed25519_key.pub'."
	exit 1
fi

if ! [ -e id_rsa ]
then
	echo "Error: id_rsa not found. Make sure it is located at '/root/.ssh/id_rsa'."
	exit 2
fi

chown root:root id_rsa
chmod 600 id_rsa

key="$(head -n 1 ssh_host_ed25519_key.pub | cut -d ' ' -f1-2)"
if [ -z "$key" ]; then exit 3; fi

echo "[$BACKUP_SERVER]:$BACKUP_PORT $key" > known_hosts
if ! [ $? = 0 ]; then exit $?; fi

if ! [ -z "$ADMIN_MAIL" ]
then
	/backup/generate_ssmtp_conf.sh
	if ! [ $? = 0 ]; then exit $?; fi
	
	if [ -z "$EMAIL_FROM" ]
	then
		echo "Error: You have set ADMIN_MAIL but not EMAIL_FROM. You need to set both."
		exit 1
	fi
fi
