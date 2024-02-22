#!/bin/bash -xe
sudo yum install httpd -y
sudo yum install git -y
sudo yum install ec2-instance-connect
systemctl enable httpd
git clone https://github.com/florient2016/myweb.git /var/www/html/web/
systemctl start httpd
