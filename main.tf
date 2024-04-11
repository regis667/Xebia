terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
 #     version = "~> 1.0.4"
    }
  }
}


resource "aws_vpc" "main" {
  # Referencing the base_cidr_block variable allows the network address
  # to be changed without modifying the configuration.
  cidr_block = var.base_cidr_block

  tags = {
	Name = "Dominik-Weremiuk-VPC"
	Owner = "dominik.weremiuk"
}
}


resource "aws_instance" "dw-server" {
  for_each       = toset(var.availability_zones)
  subnet_id = aws_subnet.dw-private[each.value].id
  ami           = "ami-02fe204d17e0189fb"
  instance_type = "t2.micro"
  user_data= file("init.sh")
  key_name = "dw"
  security_groups = [aws_security_group.web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.some_profile.id


  tags={
	Name = "Dominik-Weremiuk-ec2"
	Owner= "dominik.weremiuk"
}
depends_on=[aws_route.nat_gw, aws_db_instance.dwdb, aws_key_pair.dw]
}
resource "aws_instance" "dw-bastion" {
  #for_each       = toset(var.availability_zones)
  subnet_id = values(aws_subnet.dw-public)[0].id
  ami           = "ami-02fe204d17e0189fb"
  instance_type = "t2.micro"
  user_data= file("initbast.sh")
  key_name = "dw"
  security_groups = [aws_security_group.web_sg.id]

  tags={
	Name = "Dominik-Weremiuk-ec-bastion"
	Owner= "dominik.weremiuk"
}
depends_on=[aws_route.nat_gw, aws_db_instance.dwdb]
}
resource "aws_lb" "alb_dw" {
  name               = "dw-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [for subnet in aws_subnet.dw-public : subnet.id]

  enable_deletion_protection = false

 # access_logs {
 #   bucket  = aws_s3_bucket.dw-bucket54321.id
 #   prefix  = "test-lb"
 #   enabled = true
 # }

  tags={
	Name = "Dominik-Weremiuk-alb"
	Owner= "dominik.weremiuk"
}
depends_on=[aws_db_instance.dwdb]
}
resource "aws_lb_target_group" "target" {
  name     = "tf-lb-tg"
  port     = 5000
  protocol = "HTTP" #from HTML
  vpc_id = aws_vpc.main.id
}
resource "aws_lb_target_group" "targets3" {
  name     = "tf-lb-tgs3"
  port     = 4000
  protocol = "HTTP" #from HTML
  vpc_id = aws_vpc.main.id
}
resource "aws_lb_target_group_attachment" "target_attach" {
  target_group_arn = aws_lb_target_group.target.arn
  for_each       = toset(var.availability_zones)
  target_id        = aws_instance.dw-server[each.key].id
  #target_id = [for ec2 in aws_instance.dw-server : aws_instance.dw-server.id]
  port             = 5000
#  for_each = {
#    for k, v in aws_instance.dw-server :
#    v.id => v
#  }
#
#  target_group_arn = aws_lb_target_group.target.arn
#  target_id        = each.value.id
#  port             = 80
}
resource "aws_lb_target_group_attachment" "target_attachs3" {
  target_group_arn = aws_lb_target_group.targets3.arn
  for_each       = toset(var.availability_zones)
  target_id        = aws_instance.dw-server[each.key].id
  #target_id = [for ec2 in aws_instance.dw-server : aws_instance.dw-server.id]
  port             = 4000
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb_dw.arn
  port              = "80"
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}
resource "aws_lb_listener" "front_ends3" {
  load_balancer_arn = aws_lb.alb_dw.arn
  port              = "4000"
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets3.arn
  }
}
 resource "aws_key_pair" "dw" {
   key_name   = "dw"
   public_key= "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZKSi0YHmTZgy/q8XsUv//oDeMiVdrKxUCv/3SpQ7tfVik2pPGWNmmYIiItevbK9Ta+DRuLdxCBzQxWXqObs1Fd+atOavyc6HIFkb/+FYRcytff2B0niVpySQ04owLe1XIVMB0Wn87Z6TZ+JaY9tELuizptr4qDBiRt58NsM5P55VZbgbPVBAC+nSVOGFDYgBw5RLjY9HQaA4uRmwH3m+Al6cLf6NDCUmAhl8XVp7JIBhrOyxLCW7brlaFlOueYSaUckJ+LJLahvRFcqp/WzY3ECWkkekpTL1eWdzDtQDjIG8PtCxoIYFN8W19VeFuMi7sYAh6C1IiLsAhNtPzK6zdNZIKHJcix0WEzCXMkDuYDY93D1reppCPTVLb5Jf7+CJyJ8k4Vi35oRJ7trqZh9XAHOwottKgCPo69AowbnsxSnG2tflGEovol/WZpMmOhO3ibaeQ1utJ46XSAlWFFxJxT87oDWQW/KlMF8JxNKZ/GjnPvX5TC9ebmY47WXNjBkU= dweremiuk@DWEREMIUK-MBP.local"
 }
resource "aws_nat_gateway" "nat" {
  connectivity_type = "public"
 for_each       = toset(var.availability_zones)
  subnet_id         = aws_subnet.dw-public[each.key].id
  allocation_id=aws_eip.Nat-Gateway-EIP[each.key].id
  tags = {
    Name = "gw NAT"
  }
  depends_on = [
    aws_db_instance.dwdb
  ]
}

resource "aws_route" "nat_gw" {
#  for_each               = toset(var.availability_zones)
  route_table_id         = aws_route_table.rt_private.id
  destination_cidr_block = "0.0.0.0/0"
 nat_gateway_id         = values(aws_nat_gateway.nat)[0].id
 depends_on = [
    aws_nat_gateway.nat
  ]
}
resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "rds-subnet-group"
  subnet_ids         = [for subnet in aws_subnet.dw-public: subnet.id]

}
resource "aws_db_instance" "dwdb" {
  identifier           = "dwrds"
  allocated_storage    = 10
  db_subnet_group_name = aws_db_subnet_group.rds-subnet-group.id
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "dw"
  password             = "12345678"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db.id, aws_security_group.web_sg.id]
}

resource "aws_iam_policy" "bucket_policy" {
  name        = "my-bucket-policy"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::my-bucket-name"
        ]
      }
    ]
  })
}
resource "aws_iam_role" "some_role" {
  name = "my_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "some_bucket_policy" {
  role       = aws_iam_role.some_role.name
  policy_arn = aws_iam_policy.bucket_policy.arn
}

resource "aws_iam_instance_profile" "some_profile" {
  name = "some-profile"
  role = aws_iam_role.some_role.name
}

#-----------------------------------------------------------
output "instances" {
  value       = "${aws_instance.dw-server}"
  description = "EC2 details"
}
