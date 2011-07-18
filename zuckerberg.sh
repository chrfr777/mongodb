#!/bin/bash
#

# set the correct zuckerberg.usabilla.com (me baby, me)
if [ `mongo --quiet --eval 'rs.isMaster().ismaster'` == 'true' ]; then
	`python /root/zuckerberg.py`
fi
