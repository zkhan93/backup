#!/bin/bash
# read the message body from stdin and send it as an email using ssmtp

function usage {
    echo "Usage: $0 [-f <from>] <subject> <to>"
    echo "Options:"
    echo "  <subject>             subject of the email"
    echo "  <to>                  email address to send to"
    echo "  -f, --from            name of the sender"
    echo "  -h, --help            print this help message"
}

# check if ssmtp is installed using which 
if [ ! -f $(which ssmtp) ]; then
    echo "ssmtp not installed"
    exit 1
fi

# parse arguments using getopt
while getopts ":f:h" opt; do
    case $opt in
        f)
            SENDER=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Error: invalid option -$OPTARG"
            usage
            exit 1
            ;;
        :)
            echo "Error: option -$OPTARG requires an argument"
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))
# set default values
# if sender is not set, then use the current user
if [ -z "$SENDER" ]; then
    SENDER=$(whoami)@$(hostname)
fi
SUBJECT="Subject: $1"
TO=$2
FROM="From: $SENDER"
CONTENT_TYPE="Content-Type: text/html"

echo "SENDER: $SENDER"
echo "SUBJECT: $SUBJECT"
echo "TO: $TO"

# first line of the message body is the date, rest is the message from stdin
BODY="Sent On: $(date)\n\n$(cat)"

echo -e "$FROM\n$SUBJECT\n$CONTENT_TYPE\n\n$BODY" |  ssmtp $TO 
if [ $? -ne 0 ]; then
    echo "failed to send email"
    exit 1
else
    echo "Email sent"
fi
