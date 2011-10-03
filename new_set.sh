#!/bin/bash

source /root/config.sh
hostname=${SET_NAME}.${HOSTED_ZONE_NAME:0:${#HOSTED_ZONE_NAME}-1}
#hostname=zuckerberg.usabilla.com

# we need to figure out if ${hostname} exists, and if it is a
# primary for the replica set. if not, we (me/i) have to initiate
# the replica set, starting with ourselves.

curl="curl --retry 3 --retry-delay 15 --silent --fail"
host=${hostname}:28017

# if this returns successfully, our mongodb is probably not running there
set=$(${curl} ${host})

if [ $? -eq 0 ]; then
	result=$(mongo ${hostname} --quiet --eval 'rs.isMaster().ismaster' 2>&1)

	if [[ $result == *failed* ]]; then
		echo "yes"
	else
		echo "no"
	fi
else
	echo "yes"
fi
