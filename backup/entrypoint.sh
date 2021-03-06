#!/bin/bash

/backup/setup.sh
if ! [ $? = 0 ]
then
	echo "The initial setup failed. Shutting down container..."
	exit 1
fi

MSG="The backup of $SERVER_NAME failed:\n"
FAILED=false

echo "-----------------------------------------------------------------------------"
echo "Started backup on $(date)"
echo "-----------------------------------------------------------------------------"

mkdir -p "$BACKUP_DIR/databases/dumps"
mkdir -p "$BACKUP_DIR/databases/volume_data"
cd "$BACKUP_DIR/databases"

if [ -z "$SERVER_NAME" ]
then
	echo "Error: SERVER_NAME has not been set."
	echo "Aborting..."
	exit 1
fi

if ! [ -z "$DATABASE_BACKUP_SCHEMA" ]
then
	if [ "$DATABASE_BACKUP_SCHEMA" = "name" ]
	then
		if [ -z "$DATABASE_BACKUP_FILTER" ]
		then
			echo "Error: DATABASE_BACKUP_SCHEMA is set to '$DATABASE_BACKUP_SCHEMA' but DATABASE_BACKUP_FILTER is not set."
			echo "Aborting..."
			exit 1
		else
			db_containers=$(docker ps -q -f "name=$DATABASE_BACKUP_FILTER")
		fi
	elif [ "$DATABASE_BACKUP_SCHEMA" = "all" ]
	then
		db_containers=$(docker ps -q -f)
	fi
	
	for container in $(docker ps -q -f name=_db)
	do
		engine=$(docker exec "$container" printenv BACKUP_ENGINE)
		container_name=$(docker inspect -f '{{.Name}}' "$container" | cut -c2-)
		exit_code=0

		echo "Running backup for container '$container_name'..."

		if [ -z "$engine" ]
		then
			engine="default"
		fi
		
		if [ "$engine" = "volume" ] || ([ "$engine" = "default" ] && ! [ -z "$DATABASE_BACKUP_FORCE" ])
		then
			volumes=$(docker inspect -f '{{ range .Mounts }}{{ .Name }} {{ end }}' "$container" | awk '{$1=$1};1')
			
			if [ -z "$volumes" ]
			then
				FAILED=true
				error_msg="Error ($container_name): You chose the database backup engine '$engine' but the container has no volumes."
				MSG="${MSG}$error_msg\n"
				echo "$error_msg"
			else
				for volume in "$volumes"
				do
					if ! [ -d "$VOLUME_DIR/$volume" ]
					then
						FAILED=true
						error_msg="Error ($container_name): You chose the database backup engine '$engine' but the volume '$volume' could not be found. Make sure it is mounted to '$VOLUME_DIR/$volume'."
						MSG="${MSG}$error_msg\n"
						echo "$error_msg"
					else
						rsync -a -q -l "$VOLUME_DIR/$volume" volume_data
						if ! [ $? = 0 ]; then exit_code=100; fi

						docker stop "$container"
						if ! [ $? = 0 ]; then exit_code=100; fi

						rsync -a -q -l "$VOLUME_DIR/$volume" volume_data
						if ! [ $? = 0 ]; then exit_code=100; fi

						docker start "$container"
						if ! [ $? = 0 ]; then exit_code=100; fi
					fi
				done
			fi
		elif [ "$engine" = "mysql" ]
		then
			user=$(docker exec "$container" printenv BACKUP_USER)
			password=$(docker exec "$container" printenv BACKUP_PASSWORD)
			
			if [ -z "$user" ] || [ -z "$password" ]
			then
				FAILED=true
				error_msg="Error ($container_name): You need to specify BACKUP_USER and BACKUP_PASSWORD for database backup engine '$engine'."
				MSG="${MSG}$error_msg\n"
				echo "$error_msg"
			else
				docker exec "$container" mysqldump --all-databases -u "$user" --password="$password" > "dumps/$container_name.sql"
				exit_code=$?
			fi
		elif [ "$engine" = "postgres" ]
		then
			user=$(docker exec "$container" printenv BACKUP_USER)
			
			if [ -z "$user" ]
			then
				FAILED=true
				error_msg="Error ($container_name): You need to specify BACKUP_USER for database backup engine '$engine'."
				MSG="${MSG}$error_msg\n"
				echo "$error_msg"
			else
				docker exec "$container" pg_dumpall -U "$user" -w > "dumps/$container_name.bak"
				exit_code=$?
			fi
		elif [ "$engine" = "custom" ]
		then
			command=$(docker exec "$container" printenv BACKUP_COMMAND)
			
			if [ -z "$command" ]
			then
				FAILED=true
				error_msg="Error ($container_name): You need to specify BACKUP_COMMAND for database backup engine '$engine'."
				MSG="${MSG}$error_msg\n"
				echo "$error_msg"
			else
				docker exec "$container" bash -c "$command" > "dumps/$container_name.bak"
				exit_code=$?
			fi
		else
			FAILED=true
			error_msg="Error: Invalid BACKUP_ENGINE for '$container_name'"
			MSG="${MSG}$error_msg\n"
			echo "$error_msg"
		fi

		if ! [ $exit_code = 0 ]
		then
			FAILED=true
			error_msg="Error: Database backup for '$container_name' failed. (Exit code: $exit_code)"
			MSG="${MSG}$error_msg\n"
			echo "$error_msg"
		fi
	done
fi

if [ "$NETWORK_LIMIT" -ne "0" ]
then
	echo "Adding tc rule..."
	tc qdisc add dev eth0 root tbf rate "${NETWORK_LIMIT}mbit" burst 32kbit latency 500ms
fi

echo "Starting backup..."
rdiff-backup --print-statistics --verbosity "$VERBOSITY_LEVEL" --exclude-sockets --no-eas --no-acls $RDIFF_BACKUP_PARAMS --remote-schema "ssh -p $BACKUP_PORT -i /root/.ssh/id_rsa $SSH_PARAMS -C %s sudo rdiff-backup --server" "$BACKUP_DIR" "backupuser@$BACKUP_SERVER::$TARGET_DIR/$SERVER_NAME"
if ! [ $? = 0 ]
then
	FAILED=true
	error_msg="Rdiff Backup command failed."
	MSG="${MSG}$error_msg\n"
	echo "$error_msg"
fi

if $FAILED
then
	printf "\n\n\nBACKUP FAILED!\n"
	printf "$MSG"
	
	if ! [ -z "$ADMIN_MAIL" ]
	then
		echo "Sending mail to admin..."
		echo -e "From: $EMAIL_FROM\nTo: $ADMIN_MAIL\nSubject: Backup of '$SERVER_NAME' failed!\n\n$MSG" | ssmtp -C "$SSMTP_CONF" "$ADMIN_MAIL"
		if [ $? = 0 ]
		then
			echo "An email has been sent."
		else
			echo "Error: Failed to send an email to '$ADMIN_MAIL'. Check your ssmtp settings, ADMIN_MAIL and EMAIL_FROM."
		fi
	fi
else
	echo "Backup finished without errors."
fi
