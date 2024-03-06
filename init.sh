#!/bin/bash -xe
exec 2>&1 1>/var/init.log

yum install httpd -y
yum install git -y
yum install ec2-instance-connect -y
yum install python -y
mkdir /data
cd /data
git clone https://github.com/regis667/Xebia.git
yum update -y
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py 
cd /data/Xebia
pip install mysql-connector-python
pip install flask
pip install boto3
nohup python sql.py > /var/initsql.log 2>&1 &
( python3 s3app.py > /dev/null 2> /dev/null & ); exit