#!/bin/ksh

# get_profile.ksh
# No rights reserved, Caveat Emptor, tough if it doesn't work for you

# Written by Matt F-V for personal use and by employer.

# This script is a wrapper around a couple of utility scripts to
# ease the effort required to implement a backup strategy using
# JET and flash archives.

FLARBIN="/usr/sbin/flarcreate"
FLARNAME="$(/usr/bin/uname -n)-$(date '+%y-%m-%d-%T')"
AUGMENT_FLAR="/usr/local/bin/augment_flar.sh"
GET_PROFILE="/usr/local/bin/get_profile.ksh"

if [[ -d $1 ]];then
	echo "\nINFO: Destination set to $1\n"
	DESTINATION=$1
else
	DESTINATION="/mnt"
fi

if [[ -x $AUGMENT_FLAR ]];then
	echo "\nINFO: Creating additional recovery data..."
	$AUGMENT_FLAR
else
	echo "\nWARNING: Cannot create recovery data for /etc and other config"
	echo "         Backup will continue but config may be lost on restore.\n"
fi


if [[ -x $GET_PROFILE ]];then
	echo "\nINFO: Collecting data to create JET recovery Template..."
	$GET_PROFILE > $DESTINATION/$(uname -n).jet
else
	echo "\nWARNING: Cannot create JET profile data for recovery"
	echo "         Backup will continue but recovery may be manual.\n"
fi

echo "\nINFO: Running Flash Archive backup..."
$FLARBIN -n $FLARNAME -S -c -R / -X /etc/flar.exclude /$DESTINATION/$FLARNAME.flar
