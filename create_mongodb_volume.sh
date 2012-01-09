#!/bin/bash

source /root/config.sh

MAX_TRIES=60

status="creating"
device="/dev/sdc"
mount="/var/mongodb"

if [ ! -e "$device" ] ; then
	# ok, we are clean. now we need to figure out what to start with
	if [[ ${SET_SRC} == vol-* ]]; then
		volume_id=${SET_SRC}
	else
		if [[ ${SET_SRC} == snap-* ]]; then
			snapshot_id=${SET_SRC}
		else
			now=$(date +"%Y-%m-%d %H:%M:%S")

			snapshots=$(simpledb --max 1 select "select * from ${SET_NAME} where timestamp < '${now}' order by timestamp desc limit 1")
			snapshot_id=`expr match "$snapshots" '.*\(snap-........\).*'`
		fi

		echo "Creating the volume"
		if [[ ${snapshot_id} =~ snap-[[:alnum:]]{8} ]]; then
			volume_id=`/usr/bin/ec2-create-volume \
				--size ${SET_SIZE} \
				--snapshot ${snapshot_id} \
				--availability-zone ${EC2_AVAILABILITY_ZONE} \
				--region ${EC2_REGION} | awk '{print $2}'`
		else
			volume_id=`/usr/bin/ec2-create-volume \
				--size ${SET_SIZE} \
				--availability-zone ${EC2_AVAILABILITY_ZONE} \
				--region ${EC2_REGION} | awk '{print $2}'`
		fi
	fi

	echo ${volume_id} > ${file}

	echo "Testing the volume: ${status}"
	while [ $status != "available" ] ; do
		if [[ ${snapshot_id} =~ snap-[[:alnum:]]{8} ]]; then
			status=`/usr/bin/ec2-describe-volumes ${volume_id} \
				--region ${EC2_REGION} | awk '{print $6}'`
		else
			status=`/usr/bin/ec2-describe-volumes ${volume_id} \
				--region ${EC2_REGION} | awk '{print $5}'`
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
		/usr/bin/ec2-attach-volume ${volume_id} -i ${EC2_INSTANCE_ID} -d $device --region ${EC2_REGION}

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

		# and now we have to make sure the device is deleted on termination
		/usr/bin/ec2-modify-instance-attribute --block-device-mapping "${device}=:true" ${EC2_INSTANCE_ID} --region ${EC2_REGION}
	fi
fi

# ok, by now we should have a proper device
echo "Making filesystem"
/sbin/mkfs.xfs ${device}
echo "Growing filesystem"
/usr/sbin/xfs_growfs ${device}

echo "Mounting filesystem"
/bin/mount -t xfs -o defaults ${device} ${mount}

# and in case we start from a snapshot
/bin/rm -f /var/mongodb/lib/mongod.lock

/bin/echo "File system " ${device} " ready to be used at " ${mount}
