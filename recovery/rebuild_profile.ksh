#!/bin/ksh

# rebuilt_profile.ksh
# No rights reserved, Caveat Emptor, tough if it doesn't work for you

# Written by Matt F-V for personal use and by employer.

# This script attempts to rebuild enough of a JET profile for you
# to rebuild a solaris server from a FLAR without using too much brain
# power which will be in short simply when you're in a panic recovery!
#
# Edit the output from take_flar/get_profile to suit and run this 
# script using the basename/hostname eg myserver (not myserver.jet)
#
# This will then generate a basic template in the location configured 
# below, and merge in the get_profile output.
#
# Finally, the script runs make_client for you.

JETBASEDIR="/opt/SUNWjet"
JETMAKETEMPLATE="$JETBASEDIR/bin/make_template"
JETMAKECLIENT="$JETBASEDIR/bin/make_client"

FLARDIR="/export/flar/$1"

PRODUCTS=$(grep "base_config_products=" $FLARDIR/$1.jet | cut -d= -f2 | tr -d '"')

if [[ -f $JETBASEDIR/Templates/$1 ]]
then
 echo "INFO: Moving existing template"
 mv $JETBASEDIR/Templates/$1 $JETBASEDIR/Templates/$1.old.$$
fi

echo "INFO: creating base template with $PRODUCTS"
cd $JETBASEDIR/Templates
$JETMAKETEMPLATE $1 $PRODUCTS

echo "INFO: merging data"
IFS=''
while read line
do
 KEY=$(echo $line | cut -d = -f1)
 VALUE=$(echo $line | cut -d = -f2)
 grep -v  $KEY $JETBASEDIR/Templates/$1 > /tmp/$1.tmp
 echo "$line" >> /tmp/$1.tmp
 cp /tmp/$1.tmp $JETBASEDIR/Templates/$1
done < $FLARDIR/$1.jet

grep -v ^# $JETBASEDIR/Templates/$1 | sort -u > /tmp/$1.tmp
cp /tmp/$1.tmp $JETBASEDIR/Templates/$1

echo "INFO: running make_client"
$JETMAKECLIENT -f $1
