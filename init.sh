#!/bin/bash -xe
exec 2>&1 1>/var/init.log
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZKSi0YHmTZgy/q8XsUv//oDeMiVdrKxUCv/3SpQ7tfVik2pPGWNmmYIiItevbK9Ta+DRuLdxCBzQxWXqObs1Fd+atOavyc6HIFkb/+FYRcytff2B0niVpySQ04owLe1XIVMB0Wn87Z6TZ+JaY9tELuizptr4qDBiRt58NsM5P55VZbgbPVBAC+nSVOGFDYgBw5RLjY9HQaA4uRmwH3m+Al6cLf6NDCUmAhl8XVp7JIBhrOyxLCW7brlaFlOueYSaUckJ+LJLahvRFcqp/WzY3ECWkkekpTL1eWdzDtQDjIG8PtCxoIYFN8W19VeFuMi7sYAh6C1IiLsAhNtPzK6zdNZIKHJcix0WEzCXMkDuYDY93D1reppCPTVLb5Jf7+CJyJ8k4Vi35oRJ7trqZh9XAHOwottKgCPo69AowbnsxSnG2tflGEovol/WZpMmOhO3ibaeQ1utJ46XSAlWFFxJxT87oDWQW/KlMF8JxNKZ/GjnPvX5TC9ebmY47WXNjBkU= dweremiuk@DWEREMIUK-MBP.local" >> /home/ec2-user/.ssh/authorized_keys
chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys
chmod 600 /home/ec2-user/.ssh/authorized_keys
yum install httpd -y
yum install git -y
yum install ec2-instance-connect -y
yum install python -y
mkdir /data
cd /data
mkdir uploads
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