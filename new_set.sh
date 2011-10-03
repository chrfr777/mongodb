#!/bin/bash

result=$(mongo benioff.usabilla.com --quiet --eval 'rs.isMaster().ismaster' 2>&1)

if [[ $result == *failed* ]]; then
	echo "connection failed"
fi
