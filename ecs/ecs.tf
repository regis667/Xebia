#rozbic na stacki
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
 #     version = "~> 1.0.4"
    }
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
 #poprawic na private dla ec2
 #edytowane na public
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




#-----------------------//-----------------------
#----------------------ECS-CLUSTER---------------
resource "aws_kms_key" "kms" {
  description             = "kms"
  deletion_window_in_days = 7
}
resource "aws_ecs_cluster" "ecs_cluster" {
 name = "my-ecs-cluster"
  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.kms.arn
      logging    = "OVERRIDE"
  log_configuration {
    
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs-log.name
      }
    }
  }
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
 name = "dw-ecs-prov"

 auto_scaling_group_provider {
   auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

   managed_scaling {
     maximum_scaling_step_size = 1000
     minimum_scaling_step_size = 1
     status                    = "ENABLED"
     target_capacity           = 2
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
#Dorobic ECR
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
     image     = "public.ecr.aws/ablachowicz-public-ecr-reg/dw:sql"
     #image=hello-world
     cpu       = 256
     memory    = 512
     essential = true
     logDriver = "awslogs"
     options = {
       "awslogs-group"         = aws_cloudwatch_log_group.ecs-log.name
       "awslogs-region"        = var.aws_region
       "awslogs-stream-prefix" = "ecs"
     }
     portMappings = [
       {
         containerPort = 5000
         hostPort      = 5000
         protocol      = "tcp"
       }
     ]
   }
 ])
}


resource "aws_ecs_task_definition" "ecs_task_definition_s3" {
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
     image     = "public.ecr.aws/ablachowicz-public-ecr-reg/dw:s3"
     #image=hello-world
     cpu       = 256
     memory    = 512
     essential = true
     logDriver = "awslogs"
     options = {
       "awslogs-group"         = aws_cloudwatch_log_group.ecs-log.name
       "awslogs-region"        = var.aws_region
       "awslogs-stream-prefix" = "ecs"
     }
     portMappings = [
       {
         containerPort = 4000
         hostPort      = 4000
         protocol      = "tcp"
       }
       

     ]
   }
 ])
}

resource "aws_cloudwatch_log_group" "ecs-log" {
  name = "ecs-log"
  
  #TU WSTAW STREAM
}
resource "aws_cloudwatch_log_stream" "ecs" {
  name           = "ecs"
  log_group_name = aws_cloudwatch_log_group.ecs-log.name
}
resource "aws_ecs_service" "ecs_service" {
 name            = "ecs-service"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.ecs_task_definition.arn
 desired_count   = 2

 network_configuration {
  #bylo public
  #bylo private
   subnets         = [for subnet in aws_subnet.dw-public-ecs : subnet.id]
  # subnets = [aws_subnet.dw-private-ecs[*].id]
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
   container_port   = 5000
 }
  depends_on = [aws_autoscaling_group.ecs_asg]
#load_balancer {
#   target_group_arn = aws_lb_target_group.targets3.arn
#   container_name   = "terraform-ecs"
#   container_port   = 4000
# }
# depends_on = [aws_autoscaling_group.ecs_asg]
}
resource "aws_ecs_service" "ecs_service_s3" {
 name            = "ecs-service_s3"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.ecs_task_definition_s3.arn
 desired_count   = 2

 network_configuration {
  #bylo public
   subnets         = [for subnet in aws_subnet.dw-public-ecs : subnet.id]
  # subnets = [aws_subnet.dw-private-ecs[*].id]
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
   target_group_arn = aws_lb_target_group.targets3.arn
   container_name   = "terraform-ecs"
   container_port   = 4000
 }
#load_balancer {
#   target_group_arn = aws_lb_target_group.targets3.arn
#   container_name   = "terraform-ecs"
#   container_port   = 4000
# }
# depends_on = [aws_autoscaling_group.ecs_asg]
}