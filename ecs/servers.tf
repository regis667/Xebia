resource "aws_instance" "dw-bastion" {
  #for_each       = toset(var.availability_zones)
  subnet_id = values(aws_subnet.dw-public-ecs)[0].id
  ami           = "ami-02fe204d17e0189fb"
  instance_type = "t2.micro"
  user_data= file("initbast.sh")
  key_name = "dw"
  security_groups = [aws_security_group.web_sg.id]

  tags={
	Name = "Dominik-Weremiuk-ec-bastion"
	Owner= "dominik.weremiuk"
}
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
  depends_on=[aws_instance.dw-bastion]
}
resource "aws_iam_policy" "bucket_policy" {
  name        = "my-bucket-policy"
  path        = "/"
  description = "Allow "
#poprawic - json w json, sprawdz funkcja jsonecode
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
resource "aws_s3_bucket" "dw-bucket54321" {
  bucket = "dw-bucket54321"
  tags ={
	Name = "Dominik-Weremiuk-public-bucket"
	Owner = "dominik.weremiuk"
}
}