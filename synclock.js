#!/usr/bin/mongo admin

db.runCommand({fsync:1,lock:1});
db.currentOp();
