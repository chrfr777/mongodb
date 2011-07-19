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

status="deleting"
device=/dev/sdb
mount=/var/mongodb
file=/var/run/mongodb.volume.id

echo "Deleting the volume"
volume_id=`cat ${file}`

# and now deleting (pretty straightforward)
/bin/echo "Unmounting volume"
/bin/umount ${mount}

/bin/echo "Detaching volume"
ec2-detach-volume ${volume_id} --region ${region}

echo "Testing the volume: ${status}"
while [ "${status}" != "available" ] ; do
	status=`ec2-describe-volumes ${volume_id} --region ${region} | awk 'BEGIN {FS = "\t"} ; {if($1 ~ /VOLUME/) print $6}'`
	/bin/sleep 1
	ctr=`expr $ctr + 1`
	if [ $ctr -eq $MAX_TRIES ]; then
		if [ $status -ne "available" ]; then
			/bin/echo "WARNING: Cannot delete volume $volume_id -- Giving up after $MAX_TRIES seconds"
		fi
	fi
done

echo "Volume status: ${status}"
if [ "${status}" = "available" ]; then
	/bin/echo "Deleting volume"
	ec2-delete-volume ${volume_id} --region ${region}

	rm ${file}
fi
