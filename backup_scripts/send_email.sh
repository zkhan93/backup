#!/bin/bash
read BODY
DATE=$(date)
SUBJECT=$1
TO=$2
echo "sending email started"
printf "Subject: $SUBJECT\n\nSent On:$DATE\n\n$BODY" |  ssmtp $TO
echo "sending email exiting"
