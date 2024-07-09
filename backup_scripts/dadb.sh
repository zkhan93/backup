#!/bin/bash

# Description:
# This script pulls new photos from an Android phone to a specified local directory on a Raspberry Pi.
# It connects to the phone via ADB over a network, checks for new photos in the remote photo directory,
# and transfers only those photos that do not already exist in the local directory. The script includes
# a dry run mode to simulate the process without making any actual transfers, an option to clean up 
# phone storage by deleting copied files, and it logs progress and errors to stdout.


# Default configuration
DRY_RUN=false # Default to false
CLEAN_UP=false # Default to false

# Function to display help message
usage() {
  echo "Usage: $0 -p <PHONE_IP> -a <ADB_PORT> -r <REMOTE_PHOTO_DIR> -l <LOCAL_PHOTO_DIR> -f <FILE_PATTERN> [-d] [-c] [-h]"
  echo "  -p <PHONE_IP>         IP address of the Android phone"
  echo "  -a <ADB_PORT>         ADB port number"
  echo "  -r <REMOTE_PHOTO_DIR> Directory on the phone where photos are stored"
  echo "  -l <LOCAL_PHOTO_DIR>  Directory where you want to store photos"
  echo "  -f <FILE_PATTERN>     File pattern to match photos (e.g., *.jpg)"
  echo "  -d                    Enable dry run mode"
  echo "  -c                    Clean up phone storage after copying files"
  echo "  -h                    Display this help message"
  exit 1
}

# Parse arguments
while getopts "p:a:r:l:f:dch" opt; do
  case ${opt} in
    p )
      PHONE_IP=$OPTARG
      ;;
    a )
      ADB_PORT=$OPTARG
      ;;
    r )
      REMOTE_PHOTO_DIR=$(echo $OPTARG | sed 's:/*$::')
      ;;
    l )
      LOCAL_PHOTO_DIR=$(echo $OPTARG | sed 's:/*$::')
      ;;
    f )
      FILE_PATTERN=$OPTARG
      ;;
    d )
      DRY_RUN=true
      ;;
    c )
      CLEAN_UP=true
      ;;
    h )
      usage
      ;;
    * )
      usage
      ;;
  esac
done

# Check for mandatory arguments
if [ -z "${PHONE_IP}" ] || [ -z "${ADB_PORT}" ] || [ -z "${REMOTE_PHOTO_DIR}" ] || [ -z "${LOCAL_PHOTO_DIR}" ] || [ -z "${FILE_PATTERN}" ]; then
  usage
fi

# Function to check connectivity
check_connectivity() {
  ping -c 1 $1 &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Cannot reach $1. Please check the network connection."
    exit 1
  fi
}

# Check connectivity to Android Phone
check_connectivity $PHONE_IP

# Connect to the phone via ADB
adb connect $PHONE_IP:$ADB_PORT &> /dev/null
if [ $? -ne 0 ]; then
  echo "Error: Unable to connect to the phone via ADB. Please check the ADB connection."
  exit 1
fi

# Ensure the local photo directory exists
mkdir -p $LOCAL_PHOTO_DIR

# Get list of photos on the phone matching the pattern
phone_photos=$(adb shell ls $REMOTE_PHOTO_DIR/$FILE_PATTERN)

# Count total photos to process
total_photos=$(echo "$phone_photos" | wc -l)

# Function to display progress bar
progress_bar() {
  local progress=$1
  local total=$2
  local width=50
  local percent=$((progress * 100 / total))
  local filled=$((width * progress / total))
  local empty=$((width - filled))

  printf "\r["
  printf "%0.s#" $(seq 1 $filled)
  printf "%0.s-" $(seq 1 $empty)
  printf "] %d%% (%d/%d) - %s" $percent $progress $total "$3"
}

# Pull new photos from the phone
echo "Pulling new photos from the phone..."
current_photo=0

for photo in $phone_photos; do
  # Remove carriage return from photo name
  photo=$(echo $photo | tr -d '\r')
  # Extract base filename
  base_photo=$(basename $photo)
  status_message=""
  if [ -f "$LOCAL_PHOTO_DIR/$base_photo" ]; then
    status_message="Skipping $base_photo (already exists)"
    if [ "$CLEAN_UP" = true ] && [ "$DRY_RUN" = false ]; then
      adb shell rm $REMOTE_PHOTO_DIR/$base_photo &> /dev/null
      if [ $? -ne 0 ]; then
        status_message+=" (Error: Failed to delete photo $base_photo from phone.)"
      else
        status_message+=" (Deleted from phone.)"
      fi
    fi
  else
    if [ "$DRY_RUN" = true ]; then
      status_message="Dry run: Would transfer $REMOTE_PHOTO_DIR/$base_photo => $LOCAL_PHOTO_DIR/$base_photo"
    else
      adb pull $REMOTE_PHOTO_DIR/$base_photo $LOCAL_PHOTO_DIR &> /dev/null
      if [ $? -ne 0 ]; then
        status_message="Error: Failed to pull photo $base_photo."
      else
        status_message="Successfully pulled photo $base_photo."
        # If clean up option is enabled, delete the file from the phone
        if [ "$CLEAN_UP" = true ]; then
          adb shell rm $REMOTE_PHOTO_DIR/$base_photo &> /dev/null
          if [ $? -ne 0 ]; then
            status_message+=" (Error: Failed to delete photo $base_photo from phone.)"
          else
            status_message+=" (Deleted from phone.)"
          fi
        fi
      fi
    fi
  fi
  current_photo=$((current_photo + 1))
  progress_bar $current_photo $total_photos "$status_message"
done

echo ""
# Disconnect ADB
adb disconnect

echo -e "\nPhoto transfer completed successfully."
