#!/bin/bash
# generates /etc/ssmtp/ssmtp.conf

if ! [ -z "$SSMTP_MAILHUB" ]
then
	echo "Generating ssmtp.conf..."
	envsubst < /backup/ssmtp.conf > "$SSMTP_CONF"
fi

if ! [ -e "$SSMTP_CONF" ]
then
	echo "Generating default ssmtp.conf..."
	cp /etc/ssmtp/ssmtp.conf "$SSMTP_CONF"
fi

exit
