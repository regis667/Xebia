terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
 #     version = "~> 1.0.4"
    }
  }
}
variable "aws_region" {
default = "eu-central-1"
}

provider "aws" {
  region  = var.aws_region
#  profile = "890769921003_AdministratorAccess"
#  profile="xebia-sandbox"
  default_tags {
    tags = {
      "managed-by" = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


variable "instance_type" {
  default = "t2.micro"
}
variable "ec2_instance_name" {
  description = "Name of the EC2 instance"
  default     = "terraform-dw-ecs"
}

#variable "aws_region" {
#default = "eu-central-1"
#}

variable "base_cidr_block" {
  description = "A /16 CIDR range definition, such as 10.1.0.0/16, that the VPC will use"
  default = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "A list of availability zones in which to create subnets"
  type = list(string)
  default=["eu-central-1a", "eu-central-1b"]
}


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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_launch_template" "ecs_lt" {
 name_prefix   = "ecs-template"
 image_id      = "ami-062c116e449466e7f"
 instance_type = var.instance_type

 key_name               = "dw"
 vpc_security_group_ids = [aws_security_group.web_sg.id]
 iam_instance_profile {
   name = "ecsInstanceRole"
 }

 block_device_mappings {
   device_name = "/dev/xvda"
   ebs {
     volume_size = 30
     volume_type = "gp2"
   }
 }

 tag_specifications {
   resource_type = "instance"
   tags = {
     Name = "ecs-instance-ecs"
     Owner= "dw"
   }
 }

 user_data = filebase64("${path.module}/ecs.sh")
}

resource "aws_autoscaling_group" "ecs_asg" {
 #for_each       = toset(var.availability_zones)
 vpc_zone_identifier = [for subnet in aws_subnet.dw-public-ecs: subnet.id]
 desired_capacity    = 2
 max_size            = 3
 min_size            = 1

 launch_template {
   id      = aws_launch_template.ecs_lt.id
   version = "$Latest"
 }

 tag {
   key                 = "AmazonECSManaged"
   value               = true
   propagate_at_launch = true
 }
}

resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "rds-subnet-group"
  subnet_ids         = [for subnet in aws_subnet.dw-public-ecs: subnet.id]

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
resource "aws_s3_bucket" "dw-bucket54321" {
  bucket = "dw-bucket54321"
  tags ={
	Name = "Dominik-Weremiuk-public-bucket"
	Owner = "dominik.weremiuk"
}
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
  port              = "4000"
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets3.arn
  }
}
#-----------------------//-----------------------
#----------------------ECS-CLUSTER---------------
resource "aws_ecs_cluster" "ecs_cluster" {
 name = "my-ecs-cluster"
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
 name = "dw-ecs-prov"

 auto_scaling_group_provider {
   auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

   managed_scaling {
     maximum_scaling_step_size = 1000
     minimum_scaling_step_size = 1
     status                    = "ENABLED"
     target_capacity           = 3
   }
 }
}
resource "aws_ecs_cluster_capacity_providers" "dw-ecs-cluster-prov" {
 cluster_name = aws_ecs_cluster.ecs_cluster.name

 capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

 default_capacity_provider_strategy {
   base              = 1
   weight            = 100
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
 }
}
#------------------------//-----------------------
#-----------------------TASK-DEF----------------
resource "aws_ecs_task_definition" "ecs_task_definition" {
 family             = "my-ecs-task"
 network_mode       = "awsvpc"
 execution_role_arn = "arn:aws:iam::890769921003:role/ecsTaskExecutionRole"
 cpu                = 256
 runtime_platform {
   operating_system_family = "LINUX"
   cpu_architecture        = "X86_64"
 }
  depends_on = [aws_lb.alb_dw]
 container_definitions = jsonencode([
   {
     name      = "terraform-ecs"
     image     = "regis667/terraform-ecs:final"
     cpu       = 256
     memory    = 512
     essential = true
     portMappings = [
       {
         containerPort = 5000
         hostPort      = 5000
         protocol      = "tcp"
       },
       {
         containerPort = 80
         hostPort      = 80
         protocol      = "tcp"
       },
       {
        containerPort = 4000
        hostPort = 4000
        protocol = "tcp"
       }
     ]
   }
 ])
}

resource "aws_ecs_service" "ecs_service" {
 name            = "ecs-service"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.ecs_task_definition.arn
 desired_count   = 2

 network_configuration {
   subnets         = [for subnet in aws_subnet.dw-public-ecs : subnet.id]
   security_groups = [aws_security_group.web_sg.id]
 }

 force_new_deployment = true
 placement_constraints {
   type = "distinctInstance"
 }

 triggers = {
   redeployment = timestamp()
 }

 capacity_provider_strategy {
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
   weight            = 100
 }

 load_balancer {
   target_group_arn = aws_lb_target_group.target.arn
   container_name   = "terraform-ecs"
   container_port   = 80
 }
load_balancer {
   target_group_arn = aws_lb_target_group.targets3.arn
   container_name   = "terraform-ecs"
   container_port   = 4000
 }
 depends_on = [aws_autoscaling_group.ecs_asg]
}

