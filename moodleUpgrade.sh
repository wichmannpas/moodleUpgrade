#!/bin/bash
# This script automatically upgrades a moodle installation
# Copyright (c) 2015 Pascal Wichmann

moodlePath="/srv/http/moodle/" # change to fit path of you moodle installation
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

# genereate branch out of version
branch=$(echo $1 | cut -c1-1)$(echo $1 | cut -c3-3)

echo "starting moodle upgrade"

# create temporary directory
mkdir /tmp/moodleUpgrade
cd /tmp/moodleUpgrade

# download moodle archive and extraxt it
curl https://download.moodle.org/download.php/direct/stable$(echo $branch)/moodle-$(echo $1).tgz | tar xz

# turn moodle maintenance mode on
sudo -u $webUser $phpPath $(echo $moodlePath)admin/cli/maintenance.php --enable

# move new files
rsync -r moodle/ $moodlePath

# database upgrade
sudo -u $webUser $phpPath $(echo $moodlePath)admin/cli/upgrade.php --non-interactive

# turn maintenance mode off
sudo -u $webUser $phpPath $(echo $moodlePath)admin/cli/maintenance.php --disable

# remove temporary moodle upgrade directory
rm -rf /tmp/moodleUpgrade

echo "finished moodle upgrade"
