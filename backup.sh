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
# created by CDM - v1.0.2-alpha

##########################################################

# you can customize this variable suited on your environment

# the directory of this script located
# example: CURDIR="/root/bin/backupcdm"
CURDIR="/root/bin/backupcdm"

##########################################################

# this variable also can be changed but better not to be changed unless necessary

# the config name file
# example: CONF="conf.conf"
CONF="conf.conf"

# path for mysqldump
# example: MYSQLDUMP="/usr/bin/mysqldump"
MYSQLDUMP="/usr/bin/mysqldump"

##########################################################

# get all the variables
source $CURDIR/$CONF

# delete old log files
find $DIRLOGSCRIPT/$LOGSCRIPT*.txt -mtime +$KEEPSNAPSHOT -exec rm {} \;

# set the log file name with date
LOGSCRIPT="$DIRLOGSCRIPT/$LOGSCRIPT-`date +%Y%m%d-%H%M`.txt"

echo "`date` - Starting script" > $LOGSCRIPT

# file check INCLUDE
if [ ! -f "$CURDIR/$INCLUDE" ]; then
	echo "`date` - File $CURDIR/$INCLUDE is missing -- ERROR" >> $LOGSCRIPT
	exit
fi

# file check INCLUDENAS
if [ ! -f "$CURDIR/$INCLUDENAS" ]; then
	echo "`date` - File $CURDIR/$INCLUDENAS is missing -- ERROR" >> $LOGSCRIPT
	exit
fi

# file check EXCLUDE
if [ -z "$EXCLUDE" ]; then
	FLAGEXCLUDE=0
else
	if [ -f "$CURDIR/$EXCLUDE" ]; then
		FLAGEXCLUDE=1
	else
		echo "`date` - File $CURDIR/$EXCLUDE is missing -- ERROR" >> $LOGSCRIPT
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
		echo "`date` - File $CURDIR/$EXCLUDENAS is missing -- ERROR" >> $LOGSCRIPT
		exit
	fi
fi

# restic check
if [ ! -f "$CURDIR/restic" ]; then
	echo "`date` - File $CURDIR/restic is missing -- ERROR" >> $LOGSCRIPT
	exit
fi	

# local backup
if [ $FLAGBACKUPLOCAL -eq 1 ]; then

    # export all needed restic variables
    export RESTIC_PASSWORD=$REPOPASS
    export RESTIC_REPOSITORY=$DIRREPO
    
    # clean the old snapshot first before backup
    echo "`date` - Cleaning the snapshot, keeping the last $KEEPSNAPSHOT snapshot(s)" >> $LOGSCRIPT
    echo "" >> $LOGSCRIPT
    $CURDIR/restic forget --keep-last $KEEPSNAPSHOT --prune >> $LOGSCRIPT
    
    # error check
    echo "" >> $LOGSCRIPT
    echo "`date` - Checking for error(s)" >> $LOGSCRIPT
    echo "" >> $LOGSCRIPT
    $CURDIR/restic check >> $LOGSCRIPT
    
    # do a database backup if set
    if [ $FLAGBACKUPDBLOCAL -eq 1 ]; then
        echo "" >> $LOGSCRIPT
        echo "`date` - Dumping mysql for database listed in $CURDIR/$DATABASE" >> $LOGSCRIPT
        
        # prepare the directory
        rm -rf $DIRDUMP/*.sql
        mkdir -p $DIRDUMP
        
        # dumping the database one by one
        while read line
        do
            echo "" >> $LOGSCRIPT
            echo "`date` - Dumping mysql for database $line to $DIRDUMP/$line.sql" >> $LOGSCRIPT
            echo "" >> $LOGSCRIPT
            $MYSQLDUMP -v -h$DBHOST -u$DBUSER -p$DBPASS $line > $DIRDUMP/$line.sql 2>> $LOGSCRIPT
        done < $CURDIR/$DATABASE
    fi
    
    # do the restic backup
    echo "" >> $LOGSCRIPT
    echo "`date` - Backing up all file and directory listed in $CURDIR/$INCLUDE" >> $LOGSCRIPT
    if [ $FLAGEXCLUDE -eq 0 ]; then
        echo "" >> $LOGSCRIPT
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDE >> $LOGSCRIPT
    else
        echo "`date` - Exclude file and directory listed in $CURDIR/$EXCLUDE" >> $LOGSCRIPT
        echo "" >> $LOGSCRIPT
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDE --exclude-file=$CURDIR/$EXCLUDE >> $LOGSCRIPT
    fi
    
    # error check
    echo "" >> $LOGSCRIPT
    echo "`date` - Checking for error(s)" >> $LOGSCRIPT
    echo "" >> $LOGSCRIPT
    $CURDIR/restic check >> $LOGSCRIPT
fi

# nas backup
if [ $FLAGBACKUPNAS -eq 1 ]; then
    
    # export all needed restic variables
    export RESTIC_PASSWORD=$REPOPASSNAS
    export RESTIC_REPOSITORY=$DIRREPONAS
    
    # clean the old snapshot first before backup
    echo "`date` - Cleaning the snapshot, keeping the last $KEEPSNAPSHOTNAS snapshot(s)" >> $LOGSCRIPT
    echo "" >> $LOGSCRIPT
    $CURDIR/restic forget --keep-last $KEEPSNAPSHOTNAS --prune >> $LOGSCRIPT
    
    # error check
    echo "" >> $LOGSCRIPT
    echo "`date` - Checking for error(s)" >> $LOGSCRIPT
    echo "" >> $LOGSCRIPT
    $CURDIR/restic check >> $LOGSCRIPT
    
    # do a database backup if set
    if [ $FLAGBACKUPDBNAS -eq 1 ]; then
    
        # if it is not dumped yet, then dump
        if [ $FLAGBACKUPDBLOCAL -ne 1 ]; then
            echo "" >> $LOGSCRIPT
            echo "`date` - Dumping mysql for database listed in $CURDIR/$DATABASE" >> $LOGSCRIPT
            
            # prepare the directory
            rm -rf $DIRDUMP/*.sql
            mkdir -p $DIRDUMP
        
            # dumping the database one by one
            while read line
            do
                echo "" >> $LOGSCRIPT
                echo "`date` - Dumping mysql for database $line to $DIRDUMP/$line.sql" >> $LOGSCRIPT
                echo "" >> $LOGSCRIPT
                $MYSQLDUMP -v -h$DBHOST -u$DBUSER -p$DBPASS $line > $DIRDUMP/$line.sql 2>> $LOGSCRIPT
            done < $CURDIR/$DATABASE
        fi
    fi
    
    # do the restic backup
    echo "" >> $LOGSCRIPT
    echo "`date` - Backing up all file and directory listed in $CURDIR/$INCLUDENAS" >> $LOGSCRIPT
    if [ $FLAGEXCLUDENAS -eq 0 ]; then
        echo "" >> $LOGSCRIPT
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDENAS >> $LOGSCRIPT
    else
        echo "`date` - Exclude file and directory listed in $CURDIR/$EXCLUDENAS" >> $LOGSCRIPT
        echo "" >> $LOGSCRIPT
        $CURDIR/restic backup --files-from $CURDIR/$INCLUDENAS --exclude-file=$CURDIR/$EXCLUDENAS >> $LOGSCRIPT
    fi
    
    # error check
    echo "" >> $LOGSCRIPT
    echo "`date` - Checking for error(s)" >> $LOGSCRIPT
    echo "" >> $LOGSCRIPT
    $CURDIR/restic check >> $LOGSCRIPT
fi

echo "" >> $LOGSCRIPT
echo "`date` - Script done" >> $LOGSCRIPT
exit
