#!/bin/bash -xe
exec 2>&1 1>/var/init.log

yum install httpd -y
yum install git -y
yum install ec2-instance-connect -y
#systemctl enable httpd
#systemctl start httpd
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
nohup python sql.py > /var/initsql.log 2>&1 &