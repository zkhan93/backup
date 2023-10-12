#!/bin/bash
# read the message body from stdin and send it as an email using ssmtp

function usage {
    echo "Usage: $0 <subject> <to>"
    echo "Options:"
    echo "  <subject>             subject of the email"
    echo "  <to>                  email address to send to"
    echo "  -h, --help            print this help message"
}

# check if ssmtp is installed using which 
if [ ! -f $(which ssmtp) ]; then
    echo "ssmtp not installed"
    exit 1
fi

# parse arguments
# if -h or --help is passed, print usage and exit
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
    exit
fi

# check if all arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "missing subject or to address"
    usage
    exit 1
fi

# set default values
SUBJECT="Subject: $1"
TO=$2
# first line of the message body is the date, rest is the message from stdin
BODY="Sent On: $(date)\n\n$(cat)"
echo -e "$SUBJECT\n\n$BODY" |  ssmtp $TO
echo "email sent to $TO"
