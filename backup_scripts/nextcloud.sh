#!/bin/bash
# connects to a nextcloud instance and runs the occ command
# nextcloud.sh -s oci-somnath -n nextcloud_nextcloud -c "maintenance:mode --on"

function print_help {
  echo "Usage: $0 -s <server> -n <nextcloud-container> -c <command>"
  echo "  -s | --server )        server name"
  echo "  -n | --nextcloud )     nextcloud container name"
  echo "  -c | --command )       occ command to run"
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
    -n | --nextcloud )      shift
                            nextcloud=$1
                            ;;
    -c | --command )        shift
                            command=$1
                            ;;
    * )                     print_help
                            exit 1
  esac
  shift
done

# fail if any of the arguments are not set
if [ -z "$server" ] || [ -z "$nextcloud" ] || [ -z "$command" ]
then
  echo "Invalid arguments"
  print_help
  exit 1
fi

# check if ssh and scp are installed
if [ ! -f /usr/bin/ssh ] || [ ! -f /usr/bin/scp ]
then
  echo "ssh or scp not installed"
  exit 1
fi

# check if server is reachable, server name can be a hostname from ~/.ssh/config 
ssh $server "echo 'server reachable'"
if [ $? -ne 0 ]
then
  echo "server not reachable"
  exit 1
fi

# check if nextcloud container is running
ssh $server "docker ps | grep $nextcloud | grep Up"
if [ $? -ne 0 ]
then
  echo "nextcloud container not running"
  exit 1
fi

# run the command
ssh $server "docker exec -u www-data $nextcloud php /var/www/html/occ $command"
if [ $? -ne 0 ]
then
  echo "command failed"
  exit 1
fi

exit 0
