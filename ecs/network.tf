resource "aws_vpc" "main-ecs" {
  # Referencing the base_cidr_block variable allows the network address
  # to be changed without modifying the configuration.
  cidr_block = var.base_cidr_block

  tags = {
	Name = "Dominik-Weremiuk-VPC"
	Owner = "dominik.weremiuk"
}
}
resource "aws_subnet" "dw-public-ecs" {
  for_each                = toset(var.availability_zones)
  cidr_block = cidrsubnet(aws_vpc.main-ecs.cidr_block, 2, index(var.availability_zones, each.key))
  vpc_id                  = aws_vpc.main-ecs.id
  availability_zone       = each.key
  map_public_ip_on_launch = true
  
  
  tags = {
     Name = "Dominik-Weremiuk-public_subnet-ecs"
     Owner = "dominik.weremiuk"
}
}
resource "aws_subnet" "dw-private-ecs" {

  for_each=toset(var.availability_zones)
  availability_zone       = each.key
  vpc_id = aws_vpc.main-ecs.id
  cidr_block = cidrsubnet(aws_vpc.main-ecs.cidr_block, 2, index(var.availability_zones, each.key)+2)
  tags = {
	Name = "Dominik-Weremiuk-private_subnet-ecs"
	Owner = "dominik.weremiuk"
}
}

resource "aws_internet_gateway" "gw" {
vpc_id=aws_vpc.main-ecs.id
tags = {
        Name = "Dominik-Weremiuk-ig"
        Owner = "dominik.weremiuk"
}
}

resource "aws_route_table" "rt_public-ecs" {

vpc_id=aws_vpc.main-ecs.id

route {
cidr_block=aws_vpc.main-ecs.cidr_block
gateway_id= "local"
}
route {
cidr_block="0.0.0.0/0"
gateway_id= aws_internet_gateway.gw.id
}
tags ={
Name = "Dominik-Weremiuk-public_subnet"
Owner = "dominik.weremiuk"
}
}

resource "aws_route_table" "rt_private-ecs" {

vpc_id=aws_vpc.main-ecs.id

route {
cidr_block=aws_vpc.main-ecs.cidr_block
gateway_id= "local"
}

tags ={
Name = "Dominik-Weremiuk-private_subnet"
Owner = "dominik.weremiuk"
}
}

#sprawdzic czy to w ogole ma sens 
resource "aws_route_table_association" "public" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.dw-public-ecs[each.key].id 
  route_table_id=aws_route_table.rt_public-ecs.id
}

resource "aws_route_table_association" "private" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.dw-private-ecs[each.key].id 
  route_table_id=aws_route_table.rt_private-ecs.id
}

resource "aws_security_group" "db" {
  name   = "rds sec"
  vpc_id = aws_vpc.main-ecs.id
  tags={
	Name = "Dominik-Weremiuk-secu-group"
	Owner= "dominik.weremiuk"
}
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Dodac secu oddzielnie dla ecs-service
resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH and flask"
  vpc_id = aws_vpc.main-ecs.id
  tags={
	Name = "Dominik-Weremiuk-secu-group"
	Owner= "dominik.weremiuk"
}
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
  description = "Allow ephemeral ports"
  from_port   = 49153
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}



#----------------------LB-------------------------
resource "aws_lb" "alb_dw" {
  name               = "dw-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [for subnet in aws_subnet.dw-public-ecs : subnet.id]

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
  target_type = "ip"
  vpc_id = aws_vpc.main-ecs.id
   health_check {
   path = "/"
 }
}
resource "aws_lb_target_group" "targets3" {
  name     = "tf-lb-tgs3"
  port     = 4000
  protocol = "HTTP" #from HTML
  target_type = "ip"
  vpc_id = aws_vpc.main-ecs.id
   health_check {
   path = "/"
 }
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
  port              = "5000"
  protocol          = "HTTP"
 # ssl_policy        = "ELBSecurityPolicy-2016-08"
 #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"
#
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets3.arn
  }
}