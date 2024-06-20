#! /bin/bash
# script to create MySQL db dump of running MySQL server in a docker container either locally or remotely
# with a specific user.

shopt -s huponexit

function print_help {
  echo "Usage: $0 -s <server> -p <port> -u <user> -d <dest-dir> -c <container> -P <password>"
  echo "  -s | --server )        server name (optional) (default: localhost)"
  echo "  -p | --port )          port to connect to (optional) (default: 3306)"
  echo "  -u | --user )          MySQL user (optional) (default: root)"
  echo "  -d | --dest-dir )      directory to copy backup file to"
  echo "  -c | --container )     MySQL container name"
  echo "  -P | --password )      MySQL user password"
  echo "  -h | --help )          print this help"
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
  print_help
  exit 0
fi

# parse arguments
while [ "$1" != "" ]; do
  case $1 in
    -s | --server )         shift
                            server=$1
                            ;;
    -p | --port )           shift
                            port=$1
                            ;;
    -u | --user )           shift
                            user=$1
                            ;;
    -d | --dest-dir )       shift
                            dest_dir=$1
                            ;;
    -c | --container )      shift
                            container=$1
                            ;;
    -P | --password )       shift
                            password=$1
                            ;;
    * )                     print_help
                            exit 1
  esac
  shift
done

# set default values
if [ -z "$server" ]
then
  server="localhost"
fi

if [ -z "$port" ]
then
  port="3306"
fi

if [ -z "$user" ]
then
  user="root"
fi

# fail if any of the arguments are not set
if [ -z "$dest_dir" ] || [ -z "$container" ] || [ -z "$password" ]
then
  echo "Invalid arguments"
  print_help
  exit 1
fi

# expland the dest dir, if ~ or . is used
dest_dir=$(readlink -f $dest_dir)

function check_binary_for_remote {
  if [ ! -f /usr/bin/ssh ] || [ ! -f /usr/bin/scp ]
  then
    echo "ssh or scp not installed"
    exit 1
  fi
}
function check_binary_for_local {
  if [ ! -f /usr/bin/docker ] ||  [ ! -f /usr/bin/gzip ]
  then
    echo "docker not installed"
    exit 1
  fi
}

function check_binary_in_remote {
  $ssh "which gzip"
  if [ $? -ne 0 ]
  then
    echo "gzip not installed on remote"
    exit 1
  fi
}

function check_server_reachable {
  ssh $server "echo 'server reachable'"
  if [ $? -ne 0 ]
  then
    echo "server not reachable"
    exit 1
  fi
}

is_local=true
ssh=""
scp=""
# check if server is localhost
if [ "$server" != "localhost" ] && [ "$server" != "127.0.0.1" ]
then
  check_binary_for_remote
  check_server_reachable
  is_local=false
  ssh="ssh -t -t $server"
  scp="scp $server"
  check_binary_in_remote
else
  check_binary_for_local
fi

# check if MySQL container is running
function check_container_running {
  # if ssh is not empty, then it is remote
  if [ "$is_local" = true ]
  then
    docker ps | grep $container | grep Up
  else
    $ssh "docker ps | grep $container | grep Up"
  fi
  if [ $? -ne 0 ]
  then
    echo "MySQL container $container not running"
    exit 1
  fi
}

function create_folder() {
    if [ "$is_local" = true ]
    then
      if [ ! -d $dest_dir ]
      then
        mkdir -p $dest_dir
      fi
    else
        $ssh "mkdir -p $tmp_dir"
        if [ $? -ne 0 ]
        then
          echo "failed to create tmp dir on remote"
          exit 1
        fi
    fi
}

function copy_backup {
  echo "copying backup file from remote $server:$tmp_dir to $dest_dir"
  $scp:$tmp_dir/$filename $dest_dir
  if [ $? -ne 0 ]
  then
    echo "failed to copy backup file"
    exit 1
  fi
  echo "backup copied"
}
function cleanup_remote {
# stop any running ssh connection started by this script
  echo "cleaning up remote"
  $ssh "rm -rf $tmp_dir/$filename"
  if [ $? -ne 0 ]
  then
    echo "failed to cleanup remote"
    exit 1
  fi
  echo "clean up done"
}

function wait_for_remote_process {
  while [ $? -eq 0 ]
  do
    sleep 3
    echo "waiting ..."
  done
} 

function backup_remote {
#   trap stop_backup_remote INT TERM
  echo "creating backup on remote $server:$tmp_dir"
  $ssh "docker exec -t $container mysqldump -u $user -p$password --all-databases | gzip > $tmp_dir/$filename"
#   wait_for_remote_process
  if [ $? -ne 0 ]
  then
    echo "failed to create backup"
    exit 1
  fi
  echo "backup created"
}

function stop_backup_remote {
    # kill the sub process if any
    echo "stopping backup on remote"
    # get the pid of the process
    cid=$($ssh "ps -ef | grep 'mysqldump -u $user' | grep -v grep | awk '{print \$2}'")
    # cid is list of pids, kill all of them
    for c in $cid
    do
      $ssh "kill -9 $c"
      echo "sent kill signal to $c"
    done
    exit 1
}

filename="mysql-dumpall-`date +%Y-%m-%d-%H-%M-%S`.gz"
tmp_dir="/var/tmp/mysql-backup"

check_container_running
create_folder


if [ "$is_local" = true ]
then
  echo "creating backup locally"
  docker exec -t $container mysqldump -u $user -p$password --all-databases > /tmp/db_backup.sql
  if [ $? -ne 0 ]; then
    echo "docker exec command failed"
    exit 1
  fi
  gzip /tmp/db_backup.sql
  if [ $? -ne 0 ]; then
    echo "gzip command failed"
    exit 1
  fi
  rm /tmp/db_backup.sql
  mv /tmp/db_backup.sql.gz $dest_dir/$filename
  if [ $? -ne 0 ]; then
    echo "Failed to move the backup file to the destination directory"
    exit 1
  fi
else
  backup_remote
  copy_backup
  trap cleanup_remote EXIT
fi

echo "backup created on $server:$dest_dir"
