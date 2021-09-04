#!/bin/bash

##########################################################

# this is a shell script with some features for backup with restic backend
# before use, make sure you there is already:
# - configured conf.conf inside conf directory
# - configured include file inside conf directory
# - restic (no need to install, just copy the binary into the same directory as this script), rename it into 'restic' and then chmod +x it so it became executable
#   but if you install restic, then just change the resticdir value to restic path in the conf/conf.conf
# any variables you need to change is on the config file (./conf/conf.conf)
# created by CDM - v2.0.9

##########################################################

# list all functions, to simplify script

# dump db
dump_db () {
  echo -e "\n$(date) - Dumping database listed in $dbinclude"
  
  # prepare the directory for database dump
  if [ ! -d $dumpdir ]; then
    mkdir -p $dumpdir
  else
    rm -rf $dumpdir/*
  fi
  
  # dumping the database one by one. Check the database type, 1 is mysql; 2 is postgresql; 3 is mssql; 4 is mongodb
  if [ $dbtype -eq 1 ]; then
    while read line
    do
      echo -e "\n$(date) - Dumping mysql database $line to $dumpdir/$line.sql\n"
      $mysqldump $mysqldumpopts $line > $dumpdir/$line.sql
    done < $dbinclude
  elif [ $dbtype -eq 2 ]; then
    while read line
    do
      echo -e "\n$(date) - Dumping postgresql database $line to $dumpdir/$line.sql\n"
      $pgdump $pgdumpopts $line > $dumpdir/$line.sql
    done < $dbinclude
  elif [ $dbtype -eq 3 ]; then
    while read line
    do
      echo -e "\n$(date) - Backing up mssql database $line\n"
      $sqlcmd $sqlcmdopts -Q "BACKUP DATABASE [$line] TO DISK='$line.bak'" < /dev/null
      echo -e "\n$(date) - Moving the $sqldir/$line.bak to $dumpdir\n"
      mv $sqldir/$line.bak $dumpdir/$line.bak
    done < $dbinclude
  elif [ $dbtype -eq 4 ]; then
    $mongodump $mongodumpopts --out="$dumpdir"
  else
    echo -e "$(date) -- ERROR -- dbtype is wrong"
    exit
  fi
}

# elasticsearch backup
elasticsearch_snapshot () {
  echo -e "$(date) - Removing the elasticsearch snapshot, keeping the last $keepsnapshotes snapshot(s)\n"
  delloop="$(curl -s -XGET "localhost:9200/_snapshot/$reposnapes/_all" | jq -r ".snapshots[:-$keepsnapshotes][].snapshot")"
  for del in $delloop
  do
    echo -e "$(date) - Deleting snapshot: $del"
    curl -s -XDELETE "localhost:9200/_snapshot/$reposnapes/$del?pretty"
  done
  echo -e "$(date) - Backing up elasticsearch"
  snapshotes="$(date +%Y%m%d-%H%M)"
  curl -s -XPUT "localhost:9200/_snapshot/$reposnapes/$snapshotes?wait_for_completion=true"
}

# restic repo availability check
restic_repo_availability_check () {
  if [ ! -f $RESTIC_REPOSITORY/config ]; then
    $restic init
  fi
}

# restic error check
restic_error_check () {
  echo -e "\n$(date) - Checking for error(s)\n"
  $restic check
}

# restic forget the old snapshot
restic_forget () {
  echo -e "$(date) - Cleaning the snapshot, $1 $2 snapshot(s)\n"
  if [ $2 -lt 2 ]; then
    $restic forget latest --prune
  else
    reducedsnapshot=$(expr $2 - 1)
    $restic forget $1 $reducedsnapshot --prune
  fi
}

# restic backup
restic_backup () {
  echo -e "\n$(date) - Backing up all file and directory listed in $include and exclude file and directory listed in $exclude\n"
  if [ $flagexclude -eq 0 ]; then
    $restic backup --files-from $include
  else
    $restic backup --files-from $include --exclude-file=$exclude
  fi
}

##########################################################

# this is the main function, script start here

# let script exit if a command fails
set -o errexit

# let script exit if an unused variable is used
set -o nounset

# set some static variables before reading the config file
readonly curdir="$(dirname "$(readlink -f "$0")")"
readonly confdir="$curdir/conf"

# folder check conf
if [ ! -d $confdir ]; then
  echo -e "$(date) -- ERROR -- $confdir missing"
  exit
fi

# file check conf
if [ ! -f $confdir/conf.conf ]; then
  touch $confdir/conf.conf
fi

# get variables from default file and the conf file
source $confdir/default.conf
source $confdir/conf.conf

# set static variables
readonly log="$logdir/$logprefix-$(date +%Y%m%d-%H%M).txt"
readonly include="$confdir/include.txt"
readonly exclude="$confdir/exclude.txt"
readonly dbinclude="$confdir/dbinclude.txt"
readonly lockfile="$curdir/backupcdm.lock"

# make the folder if the log folder doesn't exist
if [ ! -d $logdir ]; then
  mkdir -p $logdir
fi

# output all of the script to the log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$log 2>&1

echo -e "$(date) - Starting script"

# protection for not running multiple scripts on the same time
if [ -f $lockfile ]; then
  echo -e "$(date) -- ERROR -- Script is locked, whether it is still running or failed on last run. Please check the log and delete the $lockfile to try again"
  if [ $notify -eq 1 ]; then  
    curl -k -s -X POST -F "hostname=$HOSTNAME" $notifysite
  fi
  exit
fi
touch $lockfile

# file check include
if [ ! -f "$include" ] || [ ! -s "$include" ]; then
  touch $include
  echo -e "$(date) -- ERROR -- Please fill the $include with list file / folder to backup"
  exit
fi

# file check exclude
if [ ! -f "$exclude" ] || [ ! -s "$exclude" ]; then
  touch $exclude
  flagexclude=0
else
  flagexclude=1
fi

# file check database
if [ $backupdb -eq 1 ]; then
  if [ ! -f "$dbinclude" ] || [ ! -s "$dbinclude" ]; then
    touch $dbinclude
    if [ $dbtype -ne 4 ]; then
      echo -e "$(date) -- ERROR -- Please fill the $dbinclude with list database to backup"
      exit
    fi
  fi
  if ! grep -q "$dumpdir" "$include"; then
    echo -e "$dumpdir" >> $include
  fi
fi

# file check elasticsearch
if [ $backupes -eq 1 ]; then
  if [ ! -d $repoes ]; then
    echo -e "$(date) -- ERROR -- Please configure manually your elasticsearch backup first"
    exit
  fi
  if ! grep -q "$repoes" "$include"; then
    echo -e "$repoes" >> $include
  fi
fi

# file check restic
if [ ! -f "$restic" ]; then
  echo -e "$(date) -- ERROR -- File $restic is missing"
  exit
fi

# delete old log files
echo -e "$(date) - Deleting old log files on $logdir"
if [ $keepsnapshot -ge $keepsnapshotnas ]; then
  find $logdir/$logprefix*.txt -mtime +$keepsnapshot -exec rm {} \;
else
  find $logdir/$logprefix*.txt -mtime +$keepsnapshotnas -exec rm {} \;
fi

# do a dump database if set
if [ $backupdb -eq 1 ]; then
  dump_db
fi

# do elasticsearch backup if set
if [ $backupes -eq 1 ]; then
  elasticsearch_snapshot
fi

# export restic password
export RESTIC_PASSWORD=$repopass

# local backup
if [ $backuplocal -eq 1 ]; then

  # export restic repo directory
  export RESTIC_REPOSITORY=$repodir
  
  # check for repo availability
  restic_repo_availability_check
  
  # check for error first
  restic_error_check
  
  # forget the old snapshot first before backup
  restic_forget $resticforgetopts $keepsnapshot
  
  # check for error again
  restic_error_check
  
  # do the restic backup
  restic_backup
  
  # last check for the error
  restic_error_check
  
  # nas backup only using cp
  if [ $backupcpnas -eq 1 ]; then
    echo -e "\n$(date) - Removing nas backup"
    rm -rf $reponasdir
    echo -e "$(date) - Copying to nas"
    cp -pr $repodir $reponascpdir
    export RESTIC_REPOSITORY=$reponasdir
    restic_error_check
  fi
fi

# nas backup
if [ $backupnas -eq 1 ]; then
  
  # mount the repo if automount = 1
  if [ $automount -eq 1 ]; then
    echo -e "$(date) -- Mounting $reponasmount"
    mount $reponasmount
  fi
  
  # export restic repo directory
  export RESTIC_REPOSITORY=$reponasdir
  
  # check for repo availability
  restic_repo_availability_check
  
  # check for error first
  restic_error_check
  
  # forget the old snapshot first before backup
  restic_forget $resticforgetnasopts $keepsnapshotnas
  
  # check for error again
  restic_error_check
  
  # do the restic backup
  restic_backup
  
  # last check for the error
  restic_error_check
  
  # unmount the repo if automount = 1
  if [ $automount -eq 1 ]; then
    echo -e "$(date) -- Unmounting $reponasmount"
    umount $reponasmount
  fi
fi

echo -e "\n$(date) - Script finished without error"
rm -f $lockfile
exit
