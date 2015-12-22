#!/bin/bash
# This script automatically upgrades a moodle installation and creates a backup of all important data before doing so
# Copyright (c) 2015 Pascal Wichmann

moodlePath="/srv/http/moodle/" # change to fit path of you moodle installation
moodleDataPath="/srv/moodledata/" # change to fit path of your moodledata directory
backupDir="/backup" # change to fit path where your backup should be placed
backupVersions=5
mysqlBackup=false  # to enable mysql backup, your user needs to have a valid mysql client configuration (i.e. .my.cnf) in order to authenticate; it may be possible to authenticate interactively, however, the easiest way is to configure the mysql client correctly
mysqlBackup_database="moodle"
webUser="www-data"
phpPath="/usr/bin/php"

if [ "$1" == "-h" ] || [ "$1" == "" ]; then
  echo "Usage: moodleUpgrade.sh version"
  echo " version: You need to specify the version which should be installed (i.e. 2.9.1)"
  echo "Script written by Pascal Wichmann, Copyright (c) 2015"
  exit 0
fi

# check if temporary directory exists (Indicating a running process of this upgrade script)
if [ -d "/tmp/moodleUpgrade" ]; then
  echo "Temporary directory /tmp/moodleUpgrade is already existing. Remove it  and start the script again, but first make sure that there is NO OTHER INSTANCE of this script running."
  exit 0
fi

# validate backup versions parameter
if ! [ -z $(echo $backupVersions | tr -d 0-9) ] || [ -z "$backupVersions" ]; then  # check that the versions parameter for backups is a valid integer
  echo "The specified backup versions parameter is invalid."
  exit 0
fi

# TODO: create a dedicated script for backup which is executed separately (to have the ability to create automated moodle backups withouth upgrade)

echo "Creating backup"

# move old backups
backupVersions=$((backupVersions-1))  # decrement backup versions count (indexing begins with 0)
# delete oldest backup (if exists)
rm -rf ${backupDir}/backup.${backupVersions} &> /dev/null
backupVersions=$((backupVersions-1))  # decrement backup versions count once again (oldest backup has already been deleted)

while [ $backupVersions -ge 0 ]
do
  mv ${backupDir}/backup.${backupVersions} ${backupDir}/backup.$((backupVersions+1)) &> /dev/null
  backupVersions=$((backupVersions-1))
done

# create directories for newest backup (and parents if backupDir does not exist yet)
mkdir -p ${backupDir}/backup.0/files

# create backup of files
rsync -a ${moodlePath} ${backupDir}/backup.0/files

# create backup of database (if enabled)
if [ $mysqlBackup = true ]; then
  mysqldump --databases ${mysqlBackup_database} > ${backupDir}/backup.0/db.sql
fi

# generate branch out of version
branch=$(echo $1 | cut -c1-1)$(echo $1 | cut -c3-3)

echo "backup finished"
echo "starting moodle upgrade"

# create temporary directory
mkdir /tmp/moodleUpgrade
cd /tmp/moodleUpgrade

# download moodle archive and extract it
curl https://download.moodle.org/download.php/direct/stable$(echo $branch)/moodle-$(echo $1).tgz | tar xz

# turn moodle maintenance mode on
sudo -u $webUser $phpPath $(echo $moodlePath)admin/cli/maintenance.php --enable

# move new files
rsync -a moodle/ $moodlePath

# database upgrade
sudo -u $webUser $phpPath $(echo $moodlePath)admin/cli/upgrade.php --non-interactive

# turn maintenance mode off
sudo -u $webUser $phpPath $(echo $moodlePath)admin/cli/maintenance.php --disable

# remove temporary moodle upgrade directory
rm -rf /tmp/moodleUpgrade

echo "finished moodle upgrade"
