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