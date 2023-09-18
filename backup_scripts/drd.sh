#! /bin/bash
# drd - download remote directory
# script to create and copy a remote directory


function print_help {
  echo "Usage: $0 -r <remote-server> -s <source-dir> -d <output-dir> -p <prefix>"
  echo "Options:"
  echo "  -r, --remote-server    remote server to connect to" # autocomplete ssh servers from ~/.ssh/config
  echo "  -s, --source           absolute directory path or docker volume name on remote server to backup"
  echo "  -d, --dest-dir         directory to copy backup file to"
  echo "  -p, --prefix           prefix to use for backup file"
  echo "  -v, --volume           treat the source-dir as a docker volume"
  echo "  -h, --help             print this help message"
}

# -v or --volume flag is passed, treat the source-dir as a docker volume use below command to create the backup 
# docker run --rm -it -v $source-dir:/data -v /tmp/dir-backup:/backup busybox tar -zcvf /backup/$FILE 

# check if last command was successful
function check_status {
  if [ $? -eq 0 ]
  then
    echo "success"
  else
    echo "failed"
    exit 1
  fi
}

function cleanup {
  echo "cleaning up"
  $ssh "rm -rf /tmp/dir-backup"
  check_status
  echo "clean up done"
}

# check if ssh and scp are installed
if [ ! -f /usr/bin/ssh ] || [ ! -f /usr/bin/scp ]
then
  echo "ssh or scp not installed"
  exit 1
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
  print_help
  exit 0
fi

# parse arguments
while [ "$1" != "" ]; do
  case $1 in
    -r | --remote-server )  shift
                            server=$1
                            ;;
    -s | --source-dir )     shift
                            source_dir=$1
                            ;;
    -d | --output-dir )     shift
                            dest_dir=$1
                            ;;
    -p | --prefix )         shift
                            prefix=$1
                            ;;
    -v | --volume )         volume=true
                            ;;
    * )                     print_help
                            exit 1
  esac
  shift
done


# fail if any of the arguments are not set
if [ -z "$server" ] || [ -z "$source_dir" ] || [ -z "$dest_dir" ] || [ -z "$prefix" ]
then
  echo "Invalid arguments"
  print_help
  exit 1
fi
# expand destination directory to absolute path, and remove trailing slash
dest_dir=$(readlink -f $dest_dir)

FILE="$prefix-`date +%Y-%m-%d-%H-%M-%S`.tar.gz"
TMP_DIR="/var/tmp/dir-backup"
TMP_FILE="$TMP_DIR/$FILE"
# create tmp dir if it doesn't exist
if [ ! -d $TMP_DIR ]
then
  mkdir -p $TMP_DIR
fi
# commands user
scp="/usr/bin/scp $server"
ssh="/usr/bin/ssh $server"

# create backup
function create_backup {
  if [ "$volume" == "true" ]
  then
    echo "creating backup of docker volume $source_dir on remote server at $TMP_FILE"
    echo $ssh "docker run --rm -v $source_dir:/data -v $TMP_DIR:/backup busybox tar -zcf /backup/$FILE /data"
    $ssh "docker run --rm -v $source_dir:/data -v $TMP_DIR:/backup busybox tar -zcf /backup/$FILE /data"
    check_status
    echo "backup created"
  else
    echo "creating backup of $source_dir on remote server at $TMP_FILE"
    $ssh "tar -zcvf $TMP_FILE $source_dir"
    check_status
    echo "backup created"
  fi  
}

function docker_cleanup {
  echo "cleaning up docker backup file"
  $ssh "docker run --rm -v $TMP_DIR:/backup busybox sh -c \"rm -rf /backup/*; sleep 2\""
  count=$($ssh "ls -1 $TMP_DIR | wc -l")
  if [ $count -eq 0 ]
  then
    echo "docker backup file cleanup done"
  else
    echo "docker backup file cleanup failed"
    exit 1
  fi
}

function copy_backup {
  echo "copying backup file locally"
  $scp:$TMP_FILE $dest_dir/$FILE
  check_status
  echo "backup copied"
}

create_backup
copy_backup
# if anything fails, cleanup
if [ "$volume" == "true" ]
then
  trap docker_cleanup EXIT
else
  trap cleanup EXIT
fi

echo "backup completed successfully at $dest_dir/$FILE"
