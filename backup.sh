#!/usr/bin/env bash


SNAR_DIR="/home/ubuntu/data/tmp"
TMP_DIR="/home/ubuntu/data/tmp"
D_DIR="/data"
S_DIR="/backup"
#DATE=$(date '+%Y%m%d_%H-%M-%S')
DATE=""
SSH_KEY="~/user.pem"


_INTERACTIVE_ () {

while [ 1 ]; do

echo -e "\nUser: "
read USER

echo -e "\nIP address of data server: "
read IP_ADDRESS

echo -e "\nDestination directory (default: /data): "
read D_DIR

echo -e "\nSource directories (default: /backup ; [delimiter is space] ): "
read S_DIR

echo -e "\nfull or inc (incremental): "
read BACKUP_TYPE



if [[ $BACKUP_TYPE == "full" || $BACKUP_TYPE == "Full" ]]; then
  M_BACKUP_TYPE="full backup"
elif [[ $BACKUP_TYPE == "inc" || $BACKUP_TYPE == "Inc" ]]; then
  M_BACKUP_TYPE="incremental backup"
else
  BACKUP_TYPE="full"
  M_BACKUP_TYPE="The backup type is not selected. Full backup Will be used"
fi

echo -e "\nIs this correct?\n"
echo "User: $USER
IP address: $IP_ADDRESS
Destination directory: $D_DIR
Source directories: $S_DIR
Backup type: $M_BACKUP_TYPE"

while [ 1 ]; do
  echo -e "\nY/N\n"
  read YN
  if [[ $YN == [YyNn] ]]; then
    break
  else
    echo "Enter Y or N"
  fi
done
[[ $YN == [Yy] ]] && break
done

}

for arg in "$@"; do

  case "$1" in
    -h|--help)
      echo " "
      echo "Options:"
      echo "-h, --help                print help"
      echo "-u                        user       "
      echo "-a                        ip addresss "
      echo "-d                        destination directory"
      echo "-s                        source directories"
      echo "-b  (full or inc)         backup type"
      echo "-i                        interactive mode"
      echo "--debug                   debug mode"
      exit 0
      ;;
    -u)
      shift
      export USER=$1
      shift
      ;;
    -a)
      shift
      export IP_ADDRESS=$1
      shift
      ;;
    -d)
      shift
      export D_DIR=$1
      shift
      ;;
    -s)
      shift
      S_DIR=""
      S_DIR+=($1)
      export S_DIR="${S_DIR[@]}"
      shift
      ;;
    -b)
      shift
      export BACKUP_TYPE=$1
      echo "BACKUP_TYPE $BACKUP_TYPE"
      shift
      ;;
    -i)
      shift
      [[ -z $1 ]] && _INTERACTIVE_
      shift
      ;;
    --debug)
      shift
      set -x
      shift
      ;;
    *)
      break
      ;;
  esac
done


_FULLBACKUP_ () {
  echo "Full backup start..."
  ssh -i $SSH_KEY $1@$2 \
  "rm -f $SNAR_DIR/$5.snar ; \
  tar --create --gzip \
  --file=$TMP_DIR/$4.tgz \
  --ignore-failed-read \
  --listed-incremental=$SNAR_DIR/$5.snar \
  $3" && echo "Ok" || echo "Error $?"
}

_INCBACKUP_ () {
  echo "Incremental backup start..."
  ssh -i $SSH_KEY $1@$2 \
  "[[ -f $SNAR_DIR/$5.snar ]] || echo \"$SNAR_DIR/$5.snar file is missing. A full backup will be created\" ; \
  tar --create --gzip \
  --file=$TMP_DIR/$4.tgz \
  --ignore-failed-read \
  --listed-incremental=$SNAR_DIR/$5.snar \
  $3" && echo "Ok" || [[ $? -eq 2 ]] && echo "Cowardly refusing to create an empty archive"
}

_DOWNLOAD_ () {
  echo "Download start... "
  ssh -i $SSH_KEY $1@$2 "[[ -f $TMP_DIR/$3.tgz ]]" ; [[ 0 -ne $? ]] && echo "File $3.tgz do not exists" && return 0
  rsync -a -e "ssh -i $SSH_KEY" \
  $1@$2:$TMP_DIR/$3.tgz $D_DIR/$4 && echo "Downloaded" || echo "Error $?"
}

for dir in $S_DIR; do
  echo -e "\nStart $dir\n"
  TG_DIR=$(basename $dir)
  DTG_DIR=$TG_DIR"_"$DATE
  if [[ $BACKUP_TYPE == "full" || $BACKUP_TYPE == "Full" ]]; then
    _FULLBACKUP_ $USER $IP_ADDRESS $dir $DTG_DIR-full $TG_DIR
    echo "Full backup was created"
    mkdir -p $D_DIR/Full $D_DIR/FullOld
    [[ 0 -lt $(ls $D_DIR/Full/$TG_DIR* 2>/dev/null | wc -w) ]] && mv $D_DIR/Full/$TG_DIR* $D_DIR/FullOld/ && logrotate -f ./logrotate-full
    _DOWNLOAD_ $USER $IP_ADDRESS $DTG_DIR-full Full/
  elif [[ $BACKUP_TYPE == "inc" || $BACKUP_TYPE == "Inc" ]]; then
    _INCBACKUP_ $USER $IP_ADDRESS $dir $DTG_DIR-inc $TG_DIR
    echo "Incremental backup was created"
    mkdir -p $D_DIR/Inc $D_DIR/IncOld
    [[ 0 -lt $(ls $D_DIR/Inc/$TG_DIR* 2>/dev/null | wc -w) ]] && mv $D_DIR/Inc/$TG_DIR* $D_DIR/IncOld/ && logrotate -f ./logrotate-inc
    _DOWNLOAD_ $USER $IP_ADDRESS $DTG_DIR-inc Inc/

  else
    echo "bye!!!"
    exit 0
  fi
  echo "$dir Done"
done

echo "The end!"
