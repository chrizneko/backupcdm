#!/bin/bash

##########################################################

# this is a script with some features for backup with restic backend
# dependency:
# - bash, echo, date, find, mysqldump (if you are backing up mysql)
# - config file named conf.conf (can be changed below), it is filled with all variables needed for this script
# - restic (no need to install, just copy the binary into the same directory as this script)
#   rename it into 'restic' and then chmod +x it so it became executable
# - make a repo with the same as DIRREPO on the conf.conf using restic init -r <the directory of the repo>
#   example: restic init -r /root/backupserver/test
# - a file that contains all the list file / folder (full path) to be backed up separated with enter, located on the same directory with this script. 
#   set the variable INCLUDE and INCLUDENAS as the name of the file
# created by CDM - v1.0.3-beta

##########################################################

# you can customize this variable suited for your environment

# the directory of this script located
# example: CURDIR="/root/bin/backupcdm"
readonly CURDIR="/root/bin/backupcdm"

# this variable also can be changed but better not to be changed unless necessary

# the config name file
# example: CONF="conf.conf"
readonly CONF="conf.conf"

##########################################################

# let script exit if a command fails
set -o errexit 

# let script exit if an unused variable is used
set -o nounset

# get all the variables
source $CURDIR/$CONF

# set the log file name with date
readonly logfile="$DIRLOGSCRIPT/$LOGSCRIPT-$(date +%Y%m%d-%H%M).txt"

# make the folder if the log folder doesn't exist
if [ ! -f $DIRLOGSCRIPT ]; then
	mkdir -p $DIRLOGSCRIPT
fi

# output all of the script to the log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$logfile 2>&1

echo "$(date) - Starting script"

# protection for not running multiple scripts on the same time
readonly lockfile="$CURDIR/backupcdm.lock"
if [ -f $lockfile ]; then
	echo "$(date) - Script is locked, whether it is still running or failed on last run -- ERROR"
	echo "$(date) - Please check the log and delete the $lockfile to try again"
	exit
fi
touch $lockfile

# delete old log files
echo "$(date) - Deleting old log files on $DIRLOGSCRIPT"
find $DIRLOGSCRIPT/$LOGSCRIPT*.txt -mtime +$KEEPSNAPSHOT -exec rm {} \;

# file check INCLUDE
if [ ! -f "$CURDIR/$INCLUDE" ]; then
	echo "$(date) - File $CURDIR/$INCLUDE is missing -- ERROR"
	exit
fi

# file check INCLUDENAS
if [ ! -f "$CURDIR/$INCLUDENAS" ]; then
	echo "$(date) - File $CURDIR/$INCLUDENAS is missing -- ERROR"
	exit
fi

# file check EXCLUDE
if [ -z "$EXCLUDE" ]; then
	FLAGEXCLUDE=0
else
	if [ -f "$CURDIR/$EXCLUDE" ]; then
		FLAGEXCLUDE=1
	else
		echo "$(date) - File $CURDIR/$EXCLUDE is missing -- ERROR"
		exit
	fi
fi

# file check EXCLUDENAS
if [ -z "$EXCLUDENAS" ]; then
	FLAGEXCLUDENAS=0
else
	if [ -f "$CURDIR/$EXCLUDENAS" ]; then
		FLAGEXCLUDENAS=1
	else
		echo "$(date) - File $CURDIR/$EXCLUDENAS is missing -- ERROR"
		exit
	fi
fi

# restic check
if [ ! -f "$CURDIR/restic" ]; then
	echo "$(date) - File $CURDIR/restic is missing -- ERROR"
	exit
fi	

# local backup
if [ $FLAGBACKUPLOCAL -eq 1 ]; then

    # export all needed restic variables
    export RESTIC_PASSWORD=$REPOPASS
    export RESTIC_REPOSITORY=$DIRREPO

    # clean the old snapshot first before backup
    echo "$(date) - Cleaning the snapshot, keeping the last $KEEPSNAPSHOT snapshot(s)"
    echo ""
    $CURDIR/restic forget --keep-last $KEEPSNAPSHOT --prune
    
    # error check
    echo ""
    echo "$(date) - Checking for error(s)"
    echo ""
    $CURDIR/restic check
    
    # do a database backup if set
    if [ $FLAGBACKUPDBLOCAL -eq 1 ]; then
        echo ""
        echo "$(date) - Dumping mysql for database listed in $CURDIR/$DATABASE"
        
        # prepare the directory
        rm -rf $DIRDUMP/*.sql
        mkdir -p $DIRDUMP
        
        # dumping the database one by one
        while read line
        do
            echo ""
            echo "$(date) - Dumping mysql for database $line to $DIRDUMP/$line.sql"
            echo ""
            mysqldump -v -h$DBHOST -u$DBUSER -p$DBPASS $line > $DIRDUMP/$line.sql
        done < $CURDIR/$DATABASE
    fi
    
    # do the restic backup
    echo ""
    echo "$(date) - Backing up all file and directory listed in $CURDIR/$INCLUDE"
    if [ $FLAGEXCLUDE -eq 0 ]; then
        echo ""
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDE
    else
        echo "$(date) - Exclude file and directory listed in $CURDIR/$EXCLUDE"
        echo ""
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDE --exclude-file=$CURDIR/$EXCLUDE
    fi
    
    # error check
    echo ""
    echo "$(date) - Checking for error(s)"
    echo ""
    $CURDIR/restic check
fi

# nas backup
if [ $FLAGBACKUPNAS -eq 1 ]; then
    
    # export all needed restic variables
    export RESTIC_PASSWORD=$REPOPASSNAS
    export RESTIC_REPOSITORY=$DIRREPONAS
    
    # clean the old snapshot first before backup
    echo "$(date) - Cleaning the snapshot, keeping the last $KEEPSNAPSHOTNAS snapshot(s)"
    echo ""
    $CURDIR/restic forget --keep-last $KEEPSNAPSHOTNAS --prune
    
    # error check
    echo ""
    echo "$(date) - Checking for error(s)"
    echo ""
    $CURDIR/restic check
    
    # do a database backup if set
    if [ $FLAGBACKUPDBNAS -eq 1 ]; then
    
        # if it is not dumped yet, then dump
        if [ $FLAGBACKUPDBLOCAL -ne 1 ]; then
            echo ""
            echo "$(date) - Dumping mysql for database listed in $CURDIR/$DATABASE"
            
            # prepare the directory
            rm -rf $DIRDUMP/*.sql
            mkdir -p $DIRDUMP
        
            # dumping the database one by one
            while read line
            do
                echo ""
                echo "$(date) - Dumping mysql for database $line to $DIRDUMP/$line.sql"
                echo ""
                mysqldump -v -h$DBHOST -u$DBUSER -p$DBPASS $line > $DIRDUMP/$line.sql
            done < $CURDIR/$DATABASE
        fi
    fi
    
    # do the restic backup
    echo ""
    echo "$(date) - Backing up all file and directory listed in $CURDIR/$INCLUDENAS"
    if [ $FLAGEXCLUDENAS -eq 0 ]; then
        echo ""
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDENAS
    else
        echo "$(date) - Exclude file and directory listed in $CURDIR/$EXCLUDENAS"
        echo ""
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDENAS --exclude-file=$CURDIR/$EXCLUDENAS
    fi
    
    # error check
    echo ""
    echo "$(date) - Checking for error(s)"
    echo ""
    $CURDIR/restic check
fi

echo ""
echo "$(date) - Script done"
rm -f $lockfile
exit
