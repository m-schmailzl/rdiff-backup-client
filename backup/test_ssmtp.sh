#!/bin/bash
# sends an email to ADMIN_MAIL

if [ -z "$ADMIN_MAIL" ]
then
	echo "Error: ADMIN_MAIL is not set."
	exit 1
fi

if [ -z "$EMAIL_FROM" ]
then
	echo "Error: EMAIL_FROM is not set."
	exit 1
fi

echo "Sending mail to admin..."

echo -e "From: $EMAIL_FROM\nTo: $ADMIN_MAIL\nSubject: schmailzl/rdiff-backup-server email test\n\nSUCCESS!" | ssmtp -C "$SSMTP_CONF" "$ADMIN_MAIL"

if [ $? = 0 ]
then
	echo "Success!"
else
	echo "Error: Failed to send an email to '$ADMIN_MAIL'. Check your ssmtp settings, ADMIN_MAIL and EMAIL_FROM."
fi
