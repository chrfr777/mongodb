#!/usr/bin/mongo admin

db.$cmd.sys.unlock.findOne();
db.currentOp();
