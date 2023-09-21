#! /bin/bash
# script to auto delete files old files from a folder

function usage {
    echo "Usage: $0 -d <directory> -e <extension> -k <number>"
    echo "Options:"
    echo "  -d, --dest             directory to delete files from"
    echo "  -e, --ext              extension of files to delete"
    echo "  -k, --keep             number of files to keep"
    echo "  -h, --help             print this help message"
    echo "      --skip-safe-check  skip safe directory check"
    echo "      --dry-run          dry run"
}

# parse arguments
while [ "$1" != "" ]; do
    case $1 in
    -d | --dest)
        shift
        DEST_DIR=$1
        ;;
    -e | --ext)
        shift
        EXT=$1
        ;;
    -k | --keep)
        shift
        KEEP=$1
        ;;
    -h | --help)
        usage
        exit
        ;;
    --dry-run)
        DRY_RUN=1
        ;;
    --skip-safe-check)
        SKIP_SAFE_CHECK=1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
done

# check if all arguments are passed
if [ -z "$DEST_DIR" ] || [ -z "$EXT" ] || [ -z "$KEEP" ]; then
    echo "missing arguments"
    usage
    exit 1
fi

# set default values
if [ -z $DRY_RUN ]; then
    DRY_RUN=0
fi

if [ -z $SKIP_SAFE_CHECK ]; then
    SKIP_SAFE_CHECK=0
fi

function check_safe_dir {
    # check if DEST_DIR is a safe location
    safe_dirs=("/backup" "/srv/dev" "/Media/CCTV")
    safe=0
    for d in "${safe_dirs[@]}"; do
        if [[ $DEST_DIR == $d* ]]; then
            safe=1
        fi
    done

    if [ $safe -eq 0 ]; then
        echo "$DEST_DIR must be a safe location, not doing anything!"
        exit 1
    fi
}

if [ $SKIP_SAFE_CHECK -eq 0 ]; then
    check_safe_dir
fi

echo "cleaning up $DEST_DIR of $EXT files to keeping last $KEEP"
# echo "Keeping last $KEEP $EXT files in $DEST_DIR"
n=$(ls $DEST_DIR/ | egrep $EXT | wc -l)
echo "total $EXT files: $n"

if [ $n -gt $KEEP ]; then
    echo "deleting $(($n - $KEEP)) $EXT files"
    for f in $(ls -t $DEST_DIR/ | egrep $EXT | tail -n +$(($KEEP + 1))); do
        echo "$f"
        if [ $DRY_RUN -eq 0 ]; then
            rm $DEST_DIR/$f
        fi
    done
    if [ $DRY_RUN -eq 1 ]; then
        echo "dry run, not deleted anything"
    fi
else
    echo "nothing to delete"
fi

echo "clean up done"
