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
		exit_code=1

		if [ -z "$engine" ]
		then
			engine="default"
		fi
		
		if [ "$engine" = "default" || "$engine" = "volume" ]
		then
			volumes=$(docker inspect -f '{{ range .Mounts }}{{ .Name }} {{ end }}' "$container")
			
			if [ -z "$volumes"]
			then
				MSG="${MSG}Error ($container_name): You chose the database backup engine '$engine' but the container has no volumes.\n"
			else
				for volume in "$volumes"
				do
					if [ -d "$VOLUME_DIR/$volume" ]
					then
						MSG="${MSG}Error ($container_name): You chose the database backup engine '$engine' but the volume '$volume' could not be found. Make sure it is mounted to '$VOLUME_DIR/$volume'.\n"
					else
						rsync -a -q -l "$VOLUME_DIR/$volume" volume_data
						if ! [ $? = 0 ]; then exit_code=1; fi

						docker stop "$container"
						if ! [ $? = 0 ]; then exit_code=1; fi

						rsync -a -q -l "$VOLUME_DIR/$volume" volume_data
						if ! [ $? = 0 ]; then exit_code=1; fi

						docker start "$container"
						if ! [ $? = 0 ]; then exit_code=1; fi
					fi
				done
			fi
		elif [ "$engine" = "mysql" ]
		then
			user=$(docker exec "$container" printenv BACKUP_USER)
			password=$(docker exec "$container" printenv BACKUP_PASSWORD)
			
			if [ -z "$user" || -z "$password" ]
			then
				MSG="${MSG}Error ($container_name): You need to specify BACKUP_USER and BACKUP_PASSWORD for database backup engine '$engine'\n"
			else
				docker exec "$container" /usr/bin/mysqldump --all-databases -u "$user" --password="$password" > "sqldumps/$container_name.sql"
				exit_code=$?
			fi
		elif [ "$engine" = "postgres" ]
		then
			user=$(docker exec "$container" printenv BACKUP_USER)
			
			if [ -z "$user" ]
			then
				MSG="${MSG}Error ($container_name): You need to specify BACKUP_USER for database backup engine '$engine'\n"
			else
				docker exec "$container" pg_dumpall -U "$user" -w > "sqldumps/$container_name.bak"
				exit_code=$?
			fi
		elif [ "$engine" = "custom" ]
		then
			command=$(docker exec "$container" printenv BACKUP_COMMAND)
			
			if [ -z "$command" ]
			then
				MSG="${MSG}Error ($container_name): You need to specify BACKUP_COMMAND for database backup engine '$engine'\n"
			else
				docker exec "$container" $command > "sqldumps/$container_name.bak"
				exit_code=$?
			fi
		else
			FAILED=true
			echo "Error: Invalid BACKUP_ENGINE for '$container_name'"
			MSG="${MSG}Error: Invalid BACKUP_ENGINE for '$container_name'\n"
		fi

		if ! [ $exit_code = 0 ]
		then
			FAILED=true
			echo "Error: Database backup for '$container_name' failed."
			MSG="${MSG}Error: Database backup for '$container_name' failed.\n"
		fi
	done
fi

if [ "$NETWORK_LIMIT" -ne "0" ]
then
	echo "Adding tc rule..."
	tc qdisc add dev eth0 root tbf rate "${NETWORK_LIMIT}mbit" burst 32kbit latency 500ms
fi

echo "Starting backup..."
rdiff-backup --print-statistics --verbosity "$VERBOSITY_LEVEL" --exclude-sockets --remote-schema "ssh -p $BACKUP_PORT -i /root/.ssh/id_rsa -C %s sudo rdiff-backup --server" "$BACKUP_DIR" "backupuser@$BACKUP_SERVER::$TARGET_DIR/$SERVER_NAME"
if ! [ $? = 0 ]
then
	FAILED=true
	MSG="${MSG}Rdiff Backup command failed.\n"
	echo "ERROR: Rdiff Backup command failed."
fi

if $FAILED
then
	echo "BACKUP FAILED!"
	
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