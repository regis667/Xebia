#!/bin/bash -xe
exec 2>&1 1>/var/init.log

sudo yum install httpd -y
sudo yum install git -y
sudo yum install ec2-instance-connect
systemctl enable httpd
systemctl start httpd
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
python sql.py > /var/init.log
