#!/bin/bash

source /root/config.sh

if [ "${ROLE}" == "arbiter" ]; then
	echo "yes"
else
	echo "no"
fi
