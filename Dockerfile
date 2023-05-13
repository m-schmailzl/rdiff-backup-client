FROM alpine:3
LABEL maintainer="maximilian@schmailzl.net"

RUN apk add --no-cache bash python3 docker-cli iproute2 coreutils ssmtp rsync rdiff-backup openssh-client tzdata gettext

COPY backup /backup
RUN chmod 700 /backup/*.sh

ENV BACKUP_DIR=/media/backup \
    VOLUME_DIR=/media/volumes \
    TARGET_DIR=/media/backups \
    SSH_PARAMS="-T -o Compression=no -x" \
    NETWORK_LIMIT=0 \
    VERBOSITY_LEVEL=3 \
    SSMTP_CONF=/root/.ssh/ssmtp.conf \
    SSMTP_AUTHMETHOD=LOGIN \
    SSMTP_TLS=yes \
    SSMTP_STARTTLS=yes

VOLUME /root/.ssh

ENTRYPOINT ["/backup/entrypoint.sh"]
