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

# set the correct zuckerberg.usabilla.com (me baby, me)
if [ `mongo --quiet --eval 'rs.isMaster().ismaster'` == 'true' ]; then
	`python /root/zuckerberg.py`
fi
