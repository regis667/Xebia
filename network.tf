resource "aws_subnet" "dw-public" {
    #tutaj przerobic na foreach dla a dw-public od AZ z
    # Create one subnet for each given availability zone.

  #count = length(var.availability_zones)

  #w foreach bedzie .key NIE count eachkey albo each value
  # For each subnet, use one of the specified availability zones.


  #availability_zone = var.availability_zones[count.index]

  # By referencing the aws_vpc.main object, Terraform knows that the subnet
  # must be created only after the VPC is created.
 #- vpc_id = aws_vpc.main.id

  # Built-in functions and operators can be used for simple transformations of
  # values, such as computing a subnet address. Here we create a /20 prefix for
  # each subnet, using consecutive addresses for each availability zone,
  # such as 10.1.16.0/20 .
  #-for_each=toset(var.availability_zones)
  #cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 2, count.index)
  for_each                = toset(var.availability_zones)
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 2, index(var.availability_zones, each.key))
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  map_public_ip_on_launch = true
  
  
  tags = {
     Name = "Dominik-Weremiuk-public_subnet"
     Owner = "dominik.weremiuk"
}
}
resource "aws_subnet" "dw-private" {

  #count = length(var.availability_zones)
  for_each=toset(var.availability_zones)
  #availability_zone = var.availability_zones[count.index]
  availability_zone       = each.key
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 2, index(var.availability_zones, each.key)+2)
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
#route {
#cidr_block="0.0.0.0/0"
#for_each=toset(var.availability_zones)
#gateway_id=aws_nat_gateway.nat
#}
tags ={
Name = "Dominik-Weremiuk-private_subnet"
Owner = "dominik.weremiuk"
}
}

#resource "aws_route_table_association" "as_public" {
#for_each = toset([for subnet in aws_subnet.dw-public: subnet.id])
#  #for_each = aws_subnet.dw-public[each.key]
#  for_each=toset(aws_subnet.dw-public[each.value])
#	route_table_id=aws_route_table.rt_public[each.key]
#	subnet_id=each.value
#	#subnet_id=aws_subnet.dw-public[count.index]
#	#route_table_id=aws_route_table.rt_public
#}
resource "aws_route_table_association" "public" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.dw-public[each.key].id 
  #route_table_id = aws_route_table.rt_public[each.key].id
  route_table_id=aws_route_table.rt_public.id
}

resource "aws_route_table_association" "private" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.dw-private[each.key].id 
  #route_table_id = aws_route_table.rt_private[each.key].id
  route_table_id=aws_route_table.rt_private.id
}
resource "aws_s3_bucket" "dw-bucket54321" {
  bucket = "dw-bucket54321"
  tags ={
	Name = "Dominik-Weremiuk-public-bucket"
	Owner = "dominik.weremiuk"
}
}
resource "aws_eip" "Nat-Gateway-EIP" {
  for_each               = toset(var.availability_zones)
  depends_on = [
    aws_route_table_association.public
  ]
  vpc = true
}

resource "aws_s3_bucket_public_access_block" "dw-bucket54321" {
  bucket = aws_s3_bucket.dw-bucket54321.id

  block_public_acls   = false
  block_public_policy = false
}
resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH and flask"
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

resource "aws_security_group" "db" {
  name   = "rds sec"
  vpc_id = aws_vpc.main.id
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