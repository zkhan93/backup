#!/bin/bash

# Check if log file is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <log_file>"
  exit 1
fi

# Define file paths and other variables
LOG_FILE="$1"
PROMPT_FILE="/backup_scripts/autorestic_email_log_prompt.txt"
SCRIPT_OPENAI="/backup_scripts/openai.sh"
SCRIPT_SEND_ALERT="/backup_scripts/autorestic_send_alert.sh"
SUBJECT="PRI Cayman Backup Report"

# Read the first 500 lines of the log file and prepare the input for OpenAI
INPUT=$(cat "$LOG_FILE" | sed '/Using config:/d; /Using env:/d; /Using lock:/d; /Skipping .* not due yet./d; /an instance is already running. exiting/d')
PROMPT=$(cat "$PROMPT_FILE")
FULL_INPUT="$INPUT\n\n==============================\n\n$PROMPT"
echo -e "$FULL_INPUT" | "$SCRIPT_OPENAI" | "$SCRIPT_SEND_ALERT" "$SUBJECT"
