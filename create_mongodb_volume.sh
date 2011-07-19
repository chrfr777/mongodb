#!/bin/bash

# Copyright (C) 2011 9Apps.net
# 
# This file is part of 9Apps/MongoDB.
# 
# 9Apps/MongoDB is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# 9Apps/MongoDB is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with 9Apps/MongoDB. If not, see <http://www.gnu.org/licenses/>.

. ~root/.ec2/ec2rc

curl="curl --retry 3 --silent --show-error --fail"
instance_data_url=http://169.254.169.254/latest
region=us-east-1

MAX_TRIES=60

instance_id=$($curl $instance_data_url/meta-data/instance-id)
availability_zone=$($curl $instance_data_url/meta-data/placement/availability-zone)

status="creating"
device="/dev/sdc"
mount="/var/mongodb"
file="/var/run/mongodb.volume.id"
if [ -e "$file" ]; then
	echo "we already have a volume...";
	exit;
fi

snapshot=$1
size=50

# if we are not we have to assume we are slave and start from
# the latest snapshot
if [[ ${snapshot} =~ snap-[[:alnum:]]{8} ]]; then
	true;
else
	now=$(date +"%Y-%m-%d %H:%M:%S")

	snapshots=$(simpledb --max 1 select "select * from zuckerberg where timestamp < '${now}' order by timestamp desc limit 1")
	snapshot=`expr match "$snapshots" '.*\(snap-........\).*'`
fi

echo "Creating the volume"
if [[ ${snapshot} =~ snap-[[:alnum:]]{8} ]]; then
	volume_id=`ec2-create-volume --snapshot ${snapshot} --availability-zone ${availability_zone} --region ${region} | awk '{print $2}'`
else
	volume_id=`ec2-create-volume --size ${size} --availability-zone ${availability_zone} --region ${region} | awk '{print $2}'`
fi

echo ${volume_id} > ${file}

echo "Testing the volume: ${status}"
while [ $status != "available" ] ; do
	if [[ ${snapshot} =~ snap-[[:alnum:]]{8} ]]; then
		status=`ec2-describe-volumes ${volume_id} --region ${region} | awk '{print $6}'`
	else
		status=`ec2-describe-volumes ${volume_id} --region ${region} | awk '{print $5}'`
	fi
	/bin/sleep 1
	ctr=`expr $ctr + 1`
	if [ $ctr -eq $MAX_TRIES ]; then
		if [ $status -ne "available" ]; then
			/bin/echo "WARNING: Cannot create volume $volume_id -- Giving up after $MAX_TRIES seconds"
		fi
	fi
done

echo "Volume status: ${status}"
if [ $status = "available" ]; then
	ec2-attach-volume ${volume_id} -i ${instance_id} -d $device --region ${region}

	/bin/echo "Testing If Volume is Attached."
	while [ ! -e "$device" ] ; do
		/bin/sleep 1
		ctr=`expr $ctr + 1`
		if [ $ctr -eq $MAX_TRIES ]; then
			if [ ! -e "$device" ]; then
				/bin/echo "WARNING: Cannot attach volume $volume_id to $device -- Giving up after $MAX_TRIES seconds"
			fi
		fi
	done
fi

if [ -e "$device" ]; then
	echo "Making filesystem"
	mkfs.xfs ${device}
	
	echo "Mounting filesystem"
	mount -t xfs -o defaults ${device} ${mount}

	# and in case we start from a snapshot
	rm -f /var/mongodb/lib/mongod.lock
	rm -f /var/mongodb/lib/local.*
fi
/bin/echo "File system " + ${device} + "created, ready to be used at " + ${mount}
