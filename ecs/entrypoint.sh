#!/usr/bin/env bash

set -e
exec 2>&1 1>/var/init.log
mkdir /data
cd /data
git clone https://github.com/regis667/Xebia.git
cd /data/Xebia
nohup python sqlinit.py 
nohup python sql.py > /var/initsql.log 2>&1 &
( python3 s3app.py >  /var/s3app.log 2>&1 & ); exit


