# rdiff-backup-client

Docker image to backup files and databases with rdiff-backup

This image is not finished yet. Description will follow.

#### Available options: 

**TZ**

**SERVER_NAME**

**BACKUP_DIR** /media/backup

**VOLUME_DIR** /media/volumes

**TARGET_DIR** /media/backups


**ADMIN_MAIL**

**EMAIL_FROM**


**BACKUP_SERVER**

**BACKUP_PORT**

**VERBOSITY_LEVEL** 3

**RDIFF_BACKUP_PARAMS**

**NETWORK_LIMIT** 0

**FREE_BACKUP_SPACE**


**DATABASE_BACKUP_SCHEMA** (name/all/none)

**DATABASE_BACKUP_FILTER**

**DATABASE_BACKUP_FORCE**


**SSMTP_CONF** /root/.ssh/ssmtp.conf

**SSMTP_MAILHUB**

**SSMTP_REWRITEDOMAIN**

**SSMTP_HOSTNAME**

**SSMTP_USER**

**SSMTP_PASSWORD**

**SSMTP_AUTHMETHOD** LOGIN

**SSMTP_TLS** yes

**SSMTP_STARTTLS** no

**SSMTP_CA_FILE**


#### Database container options: 

**BACKUP_ENGINE** (volume/mysql/postgres/custom/none)

**BACKUP_COMMAND**

**BACKUP_USER**

**BACKUP_PASSWORD**


#### Volumes:

**/media/backup** : Default backup directory

**/root/.ssh** : Keys for SSH access (must contain id_rsa and ssh_host_ed25519_key.pub)