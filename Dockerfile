FROM docker:19
MAINTAINER Maximilian Schmailzl <maximilian@schmailzl.net>

RUN apk add --no-cache bash iproute2 coreutils ssmtp rsync rdiff-backup openssh-client tzdata gettext

COPY backup /backup
RUN chmod 700 /backup/*.sh

ENV BACKUP_DIR /media/backup
ENV VOLUME_DIR /media/volumes
ENV TARGET_DIR /media/backups
ENV NETWORK_LIMIT 0 # in Mbit/s
ENV VERBOSITY_LEVEL 5
ENV SSMTP_CONF /root/.ssh/ssmtp.conf
ENV SSMTP_AUTHMETHOD LOGIN
ENV SSMTP_TLS yes
ENV SSMTP_STARTTLS no

VOLUME /root/.ssh

ENTRYPOINT ["/backup/entrypoint.sh"]
