#!/bin/bash

TO="zkhan1093@gmail.com"
SENDER="Autorestic - Cayman RPi"
SUBJECT="$1"
BODY=$(cat)

echo "$BODY" | /backup_scripts/send_email.sh -f "$SENDER" "$SUBJECT" "$TO"
