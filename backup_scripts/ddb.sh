#! /bin/bash
# script to create db dump of running db server (PostgreSQL, MongoDB, or MySQL) in a docker container either locally or remotely with a specific user.

shopt -s huponexit

function print_help {
  echo "Usage: $0 -s <server> -p <port> -u <user> -d <dest-dir> -c <container> -t <db-type>"
  echo "  -s | --server )        server name (optional) (default: localhost)"
  echo "  -p | --port )          port to connect to (optional) (default: 5432 for postgres, 27017 for mongo, 3306 for mysql)"
  echo "  -u | --user )          db user (optional) (default: postgres for postgres, root for mysql, empty for mongo)"
  echo "  -P | --password )      db password (optional) (default: empty)"
  echo "  -d | --dest-dir )      directory to copy backup file to"
  echo "  -c | --container )     database container name"
  echo "  -t | --db-type )       database type (postgres, mongo, or mysql)"
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
    -P | --password )       shift
                            password=$1
                            ;;
    -d | --dest-dir )       shift
                            dest_dir=$1
                            ;;
    -c | --container )      shift
                            container=$1
                            ;;
    -t | --db-type )        shift
                            db_type=$1
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
  case $db_type in
    postgres ) port="5432" ;;
    mongo ) port="27017" ;;
    mysql ) port="3306" ;;
    * ) echo "Unsupported database type"; exit 1 ;;
  esac
fi

if [ -z "$user" ]
then
  case $db_type in
    postgres ) user="postgres" ;;
    mongo ) user="" ;;
    mysql ) user="root" ;;
    * ) echo "Unsupported database type"; exit 1 ;;
  esac
fi

if [ -z "$password" ]
then
  password=""
fi

# fail if any of the arguments are not set
if [ -z "$dest_dir" ] || [ -z "$container" ] || [ -z "$db_type" ]
then
  echo "Invalid arguments"
  print_help
  exit 1
fi

# expand the dest dir, if ~ or . is used
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

# check if db container is running
function check_container_running {
  if [ "$is_local" = true ]
  then
    docker ps | grep $container | grep Up
  else
    $ssh "docker ps | grep $container | grep Up"
  fi
  if [ $? -ne 0 ]
  then
    echo "$db_type container $container not running"
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

function backup_postgres {
  if [ "$is_local" = true ]; then
    docker exec -t $container pg_dumpall -c -U $user | gzip > $dest_dir/$filename
  else
    $ssh "docker exec -t $container pg_dumpall -c -U $user | gzip > $tmp_dir/$filename"
  fi
}

function backup_mongo {
  if [ "$is_local" = true ]; then
    docker exec -t $container mongodump --archive --gzip --username $user --password $password > $dest_dir/$filename
  else
    $ssh "docker exec -t $container mongodump --archive --gzip --username $user --password $password > $tmp_dir/$filename"
  fi
}

function backup_mysql {
  if [ "$is_local" = true ]; then
    docker exec -t $container mysqldump -u $user -p$password --all-databases | gzip > $dest_dir/$filename
  else
    $ssh "docker exec -t $container mysqldump -u $user -p$password --all-databases | gzip > $tmp_dir/$filename"
  fi
}

filename="$db_type-dumpall-`date +%Y-%m-%d-%H-%M-%S`.gz"
tmp_dir="/var/tmp/db-backup"

check_container_running
create_folder

case $db_type in
  postgres )
    backup_postgres
    ;;
  mongo )
    backup_mongo
    ;;
  mysql )
    backup_mysql
    ;;
  * )
    echo "Unsupported database type"
    exit 1
    ;;
esac

if [ "$is_local" != true ]; then
  copy_backup
  trap cleanup_remote EXIT
fi

echo "backup created on $server:$dest_dir"
