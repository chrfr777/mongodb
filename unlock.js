#!/usr/bin/mongo admin

db.fsyncUnlock();
db.currentOP();
