#!/bin/bash -xe
sudo yum install httpd -y
sudo yum install git -y
sudo yum install ec2-instance-connect
systemctl enable httpd
systemctl start httpd
yum install python -y
git clone https://github.com/regis667/Xebia.git
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --user
pip install mysql-connector-python
pip install flask
python sql.py
