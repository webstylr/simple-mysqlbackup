#!/bin/bash
### Write log to temporary file  ###
exec &> /tmp/backuplog.txt

### Defaults Setup ###
STORAGEDIR="/path/to/backup";
NOW=`date "+%s"`;
OLDESTDIR=`ls $STORAGEDIR | head -1`;
NOWDIR=`date +"%Y-%m-%d"`;
NOWFILE=`date +"%Y-%m-%d"`;
OLDEST=`date -d "$OLDESTDIR" "+%s"`;
BACKUPDIR="$STORAGEDIR/$NOWDIR";
DIFF=$(($NOW-$OLDEST));
DAYS=$(($DIFF/ (60*60*24)));
DIRLIST=`ls -lRh $BACKUPDIR`;
ROTATION="7"
GZIPCHECK=();
### Server Setup ###
MUSER="dbuser";
MPASS="dbpassword";
MHOST="localhost";
MPORT="3306";
IGNOREDB="
information_schema
mysql
test
"
MYSQL=`which mysql`;
MYSQLDUMP=`which mysqldump`;
GZIP=`which gzip`;


### Create backup dir ###
if [ ! -d $BACKUPDIR ]; then
  mkdir -p $BACKUPDIR
    if [ "$?" = "0" ]; then
        :
    else
        echo "Couldn't create folder. Check folder permissions and/or disk quota!"
    fi
else
 :
fi

### Get the list of available databases ###
DBS="$(mysql -u $MUSER -p$MPASS -h $MHOST -P $MPORT -Bse 'show databases')"

### Backup DBs ###
for db in $DBS
do
    DUMP="yes";
    if [ "$IGNOREDB" != "" ]; then
        for i in $IGNOREDB
        do
            if [ "$db" == "$i" ]; then
                    DUMP="NO";
            fi
        done
    fi

    if [ "$DUMP" == "yes" ]; then
        FILE="$BACKUPDIR/$NOWFILE-$db.sql.gz";
        echo "BACKING UP $db";
        $MYSQLDUMP --add-drop-database --opt --lock-all-tables -u $MUSER -p$MPASS -h $MHOST -P $MPORT $db | gzip > $FILE
        if [ "$?" = "0" ]; then
            gunzip -t $FILE;
            if [ "$?" = "0" ]; then
                GZIPCHECK+=(1);
                echo `ls -alh $FILE`;
            else
                GZIPCHECK+=(0);
                echo "Exit, gzip test failed.";
            fi
        else
            echo "Dump of $db failed!"
        fi
    fi
done;

### Check if gzip test for all files was ok ###
CHECKOUTS=${#GZIPCHECK[@]};
for (( i=0;i<$CHECKOUTS;i++)); do
    CHECKSUM=$(( $CHECKSUM + ${GZIPCHECK[${i}]} ));
done 

### If all files check out, delete the oldest dir ###
if [ "$CHECKSUM" == "$CHECKOUTS" ]; then
    echo "All files checked out ok. Deleting oldest dir.";
    ## Check if Rotation is true ###
    if [ "$DAYS" -ge $ROTATION ]; then
        rm -rf $STORAGEDIR/$OLDESTDIR;
        if [ "$?" = "0" ]; then
            echo "$OLDESTDIR deleted."
        else
            ### Error message with listing of all dirs ###
            echo "Couldn't delete oldest dir.";
            echo "Contents of current Backup:";
            echo " ";
            echo $DIRLIST;
        fi
    else
        :
    fi
else
    echo "Dispatching Karl, he's an Expert";
    ### Send mail with contents of logfile ###
    #mail -s "Backuplog" mail@domain.tld < /tmp/backuplog.txt;
fi
