#!/bin/bash

source /root/config.sh

# am i ready to be the endpoint for this replica set?
if [ `mongo --quiet --eval 'rs.isMaster().ismaster'` == 'true' ]; then
	# point endpoint to me
	python /root/endpoint.py
	# and process remaining tasks
	python /root/process_tasks.py
fi
