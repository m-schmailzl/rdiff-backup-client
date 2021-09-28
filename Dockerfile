FROM alpine:3
LABEL maintainer="maximilian@schmailzl.net"

RUN apk add --no-cache bash python3 docker-cli iproute2 coreutils ssmtp rsync rdiff-backup openssh-client tzdata gettext

COPY backup /backup
RUN chmod 700 /backup/*.sh

ENV BACKUP_DIR /media/backup
ENV VOLUME_DIR /media/volumes
ENV TARGET_DIR /media/backups
ENV SSH_PARAMS "-T -o Compression=no -x"
ENV NETWORK_LIMIT 0
ENV VERBOSITY_LEVEL 3
ENV SSMTP_CONF /root/.ssh/ssmtp.conf
ENV SSMTP_AUTHMETHOD LOGIN
ENV SSMTP_TLS yes
ENV SSMTP_STARTTLS no

VOLUME /root/.ssh

ENTRYPOINT ["/backup/entrypoint.sh"]
