#!/bin/bash
# we get the replica set configuration from user-data, this way we can
# use features as auto-scaling to safeguard our setup
#
# name: this will be replica set name, but will also result in
#       setname.9apps.net and in SimpleDB/SQS
# size: the size of the volume, if one is created (see source)
# source: starting point for the replica set, if not empty it can be either
#       snapshot id or volume id. if a volume is created (if source is empty
#       or a snapshot id is given) the size will be determined above

userdata=`curl --silent http://169.254.169.254/latest/user-data`
grep="grep"
regex='s/.*\:[ \t]*"\{0,1\}\([^,"]*\)"\{0,1\},\{0,1\}/\1/'
sed="sed '${regex}'"

if [ "${userdata}" != "" ]; then
	# basic settings
	export SET_NAME=`eval "echo '${userdata}' | ${grep} '\"name\"' | ${sed}"`
	export SET_SIZE=`eval "echo '${userdata}' | ${grep} '\"size\"' | ${sed}"`
	export SET_SRC=`eval "echo '${userdata}' | ${grep} '\"source\"' | ${sed}"`
	export ROLE=`eval "echo '${userdata}' | ${grep} '\"role\"' | ${sed}"`
fi

# AWS settings
export AWS_ACCOUNT_ID=""

# EC2 settings (needs some EBS and Route53 priviliges)
export EC2_KEY_ID=""
export EC2_SECRET_KEY=""

export R53_KEY_ID=""
export R53_SECRET_KEY=""
export HOSTED_ZONE_NAME=""
export HOSTED_ZONE_ID=""

# SQS settings
export SQS_KEY_ID=""
export SQS_ACCESS_KEY=""

# some of these things are present on the instance
export EC2_KEY_DIR=/root/.ec2
export AWS_CREDENTIAL_FILE=${EC2_KEY_DIR}/aws_credentials.txt
export EC2_PRIVATE_KEY=${EC2_KEY_DIR}/pk-.pem
export EC2_CERT=${EC2_KEY_DIR}/cert-.pem
export EC2_ACCESS_KEY=${EC2_KEY_ID}
export AWS_ACCESS_KEY_ID=${EC2_KEY_ID}
export EC2_SECRET_KEY=${EC2_SECRET_KEY}
export AWS_SECRET_ACCESS_KEY=${EC2_SECRET_KEY}
export EC2_USER_ID=${AWS_ACCOUNT_ID}

curl="curl --retry 3 --silent --show-error --fail"
instance_data_url=http://169.254.169.254/latest

export EC2_AVAILABILITY_ZONE=$($curl $instance_data_url/meta-data/placement/availability-zone)
export EC2_REGION=${EC2_AVAILABILITY_ZONE:0:${#EC2_AVAILABILITY_ZONE}-1}
export EC2_INSTANCE_ID=$($curl $instance_data_url/meta-data/instance-id)

export SDB_SERVICE_URL='https://sdb.amazonaws.com'

# changing this is entirely your own responsibility, I wouldn't do it
export SQS_TASK_QUEUE="${SET_NAME}-tasks"
