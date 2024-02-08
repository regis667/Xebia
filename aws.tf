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
  profile = "890769921003_AdministratorAccess"
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
  default     = "terraform-dw"
}

#variable "aws_region" {
#default = "eu-central-1"
#}

variable "base_cidr_block" {
  description = "A /16 CIDR range definition, such as 10.1.0.0/16, that the VPC will use"
  default = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "A list of availability zones in which to create subnets"
  type = list(string)
  default=["eu-central-1a", "eu-central-1b"]
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
resource "aws_subnet" "dw-public" {
    #tutaj przerobic na foreach dla a dw-public od AZ z
    # Create one subnet for each given availability zone.

  #count = length(var.availability_zones)

  #w foreach bedzie .key NIE count eachkey albo each value
  # For each subnet, use one of the specified availability zones.


  #availability_zone = var.availability_zones[count.index]

  # By referencing the aws_vpc.main object, Terraform knows that the subnet
  # must be created only after the VPC is created.
  vpc_id = aws_vpc.main.id

  # Built-in functions and operators can be used for simple transformations of
  # values, such as computing a subnet address. Here we create a /20 prefix for
  # each subnet, using consecutive addresses for each availability zone,
  # such as 10.1.16.0/20 .
  #for_each=toset(var.availability_zones)
  #cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 2, count.index)
  for_each  = {for k, v in var.availability_zones : v => index(var.availability_zones, v)}
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 2, each.value)
  
  tags = {
     Name = "Dominik-Weremiuk-public_subnet"
     Owner = "dominik.weremiuk"
}
}
resource "aws_subnet" "dw-private" {

  #count = length(var.availability_zones)
  #for_each=toset(var.availability_zones)
  for_each  = {for k, v in var.availability_zones : v => index(var.availability_zones, v)}
  #availability_zone = var.availability_zones[count.index]
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 2, each.value+2)
  tags = {
	Name = "Dominik-Weremiuk-private_subnet"
	Owner = "dominik.weremiuk"
}
}

resource "aws_internet_gateway" "gw" {
vpc_id=aws_vpc.main.id
tags = {
        Name = "Dominik-Weremiuk-ig"
        Owner = "dominik.weremiuk"
}
}

resource "aws_route_table" "rt_public" {

vpc_id=aws_vpc.main.id

route {
cidr_block=aws_vpc.main.cidr_block
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
resource "aws_route_table" "rt_private" {

vpc_id=aws_vpc.main.id

route {
cidr_block=aws_vpc.main.cidr_block
gateway_id= "local"
}
tags ={
Name = "Dominik-Weremiuk-private_subnet"
Owner = "dominik.weremiuk"
}
}

resource "aws_route_table_association" "as_public" {
#for_each = {for k, v in aws_subnet.dw-public: v => aws_subnet.dw-public.id}
#for_each = aws_subnet.dw-public.id
for_each  = {for k, v in aws_subnet.dw-public[each.value] : v => index(aws_subnet.dw-public[each.key], v)}
#for_each = aws_subnet.dw-public.id[each.key]
#  for_each=toset(aws_subnet.dw-public[each.value])
	route_table_id=aws_route_table.rt_public.id
	subnet_id=each.value
#	#subnet_id=aws_subnet.dw-public[count.index]
#	#route_table_id=aws_route_table.rt_public
}

resource "aws_route_table_association" "as_private" {
        for_each = toset([for subnet in aws_subnet.dw-private: subnet.id])
        route_table_id=aws_route_table.rt_private.id
        subnet_id=each.value
        #subnet_id=aws_subnet.dw-public[count.index]
        #route_table_id=aws_route_table.rt_public
}

resource "aws_s3_bucket" "dw-bucket54321" {
  bucket = "dw-bucket54321"
  tags ={
	Name = "Dominik-Weremiuk-public-bucket"
	Owner = "dominik.weremiuk"
}
}


resource "aws_s3_bucket_public_access_block" "dw-bucket54321" {
  bucket = aws_s3_bucket.dw-bucket54321.id

  block_public_acls   = false
  block_public_policy = false
}
resource "aws_security_group" "web_sg" {
  name   = "web_sg"
  vpc_id = aws_vpc.main.id
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

resource "aws_instance" "dw-server" {
  ami           = "ami-02fe204d17e0189fb"
  instance_type = "t2.micro"
    user_data = <<EOF
#!/bin/bash
echo "Blablablabla bla bla!"
EOF
security_groups = [aws_security_group.web_sg.id]
#subnet_id = aws_subnet.dw-private
for_each = toset([for subnet in aws_subnet.dw-private: subnet.id])
#subnet_id = aws_subnet.dw-private[each.value]
subnet_id = each.value
  tags={
	Name = "Dominik-Weremiuk-ec2"
	Owner= "dominik.weremiuk"
}
}