#!/bin/bash

source /root/config.sh
echo ${SET_NAME}.${HOSTED_ZONE_NAME:0:${#HOSTED_ZONE_NAME}-1}
