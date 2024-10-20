terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current_caller" {}
data "aws_region" "current_region" {}

locals {
  account_id             = data.aws_caller_identity.current_caller.account_id
  region                 = data.aws_region.current_region.name
  ecs_cluster_name       = "${var.project_name}-ecs-cluster"
  ec2_instance_user_data = <<EOF
#!/bin/bash
echo "Writing 'ecs.config' file"
echo "ECS_CLUSTER=${local.ecs_cluster_name}" >> /etc/ecs/ecs.config
echo "ECS_AVAILABLE_LOGGING_DRIVERS=[\"awslogs\"]" >> /etc/ecs/ecs.config
EOF
}

##
## VPC, Internet Gateway, Subnet, Route Table
##
resource "aws_vpc" "vpc" {
  cidr_block           = "172.16.0.0/28"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-ig"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "172.16.0.0/28"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  route {
    cidr_block = "172.16.0.0/28"
    gateway_id = "local"
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

##
## Nacl
##
resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.public_subnet.id]

  egress {
    protocol   = "tcp"
    rule_no    = 10
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 20
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 30
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 10
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 20
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 30
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = {
    Name = "${var.project_name}-public-nacl"
  }
}

##
## Security Group
##
resource "aws_security_group" "ecs_cluster_sg" {
  name        = "${var.project_name}-ecs-cluster-sg"
  description = "For EC2 instances that belongs to ECS cluster"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_cluster_sg_allow_frontend" {
  security_group_id = aws_security_group.ecs_cluster_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8000
  to_port           = 8000
}

resource "aws_vpc_security_group_ingress_rule" "ecs_cluster_sg_allow_backend" {
  security_group_id = aws_security_group.ecs_cluster_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8001
  to_port           = 8001
}

resource "aws_vpc_security_group_egress_rule" "ecs_cluster_sg_allow_all" {
  security_group_id = aws_security_group.ecs_cluster_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

##
## Launch Templates
##
resource "aws_iam_role" "ec2_instance_iam_role" {
  name = "${var.project_name}-ec2-instance-iam-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "sts:AssumeRole"
        ]
        Principal : {
          Service : [
            "ec2.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "allow_ssm_session_manager_policy_attachment" {
  role       = aws_iam_role.ec2_instance_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "allow_ecs_task_execution_for_ec2_instance_policy_attachment" {
  role       = aws_iam_role.ec2_instance_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_policy" "allow_container_create_logs_in_cw_iam_policy" {
  name = "${var.project_name}-allow-container-create-logs-in-cw-iam-policy"
  policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "logs:CreateLogGroup"
        ]
        Resource : [
          "arn:aws:logs:${local.region}:${local.account_id}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "allow_container_create_logs_in_cw_policy_attachment" {
  role       = aws_iam_role.ec2_instance_iam_role.name
  policy_arn = aws_iam_policy.allow_container_create_logs_in_cw_iam_policy.arn
}

resource "aws_iam_instance_profile" "ec2_iam_instance_profile" {
  name = "${var.project_name}-ec2-iam-instance-profile"
  role = aws_iam_role.ec2_instance_iam_role.id
}

resource "aws_launch_template" "ecs_cluster_launch_template" {
  name          = "${var.project_name}-ecs-cluster-launch-template"
  image_id      = "ami-0870bdb411e0b8cec"
  instance_type = "t2.micro"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 30
      delete_on_termination = true
      encrypted             = false
    }
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_cluster_sg.id]
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_iam_instance_profile.arn
  }
  user_data       = base64encode(local.ec2_instance_user_data)
  default_version = 1
}

##
## Auto Scaling Group
##
resource "aws_iam_service_linked_role" "asg_iam_service_linked_role" {
  aws_service_name = "autoscaling.amazonaws.com"
}

resource "aws_autoscaling_group" "ecs_cluster_asg" {
  name = "${var.project_name}-ecs-cluster-asg"
  launch_template {
    id      = aws_launch_template.ecs_cluster_launch_template.id
    version = aws_launch_template.ecs_cluster_launch_template.default_version
  }
  vpc_zone_identifier = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet.id
  ]
  health_check_grace_period = 240 # 4 minutes in seconds
  health_check_type         = "EC2"
  min_size                  = 1
  desired_capacity          = 1
  max_size                  = 2

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  depends_on = [aws_iam_service_linked_role.asg_iam_service_linked_role]
}

resource "aws_autoscaling_policy" "ecs_cluster_asg_policy" {
  name        = "${var.project_name}-ecs-cluster-asg-policy"
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
  autoscaling_group_name = aws_autoscaling_group.ecs_cluster_asg.name
}

#
# ECS Cluster
#
resource "aws_iam_service_linked_role" "ecs_iam_service_linked_role" {
  aws_service_name = "ecs.amazonaws.com"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.ecs_cluster_name

  depends_on = [aws_iam_service_linked_role.ecs_iam_service_linked_role]
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "${var.project_name}-ecs-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_cluster_asg.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity_provider" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]
}

##
## ECS Task Definition
##
resource "aws_ecs_task_definition" "frontend_task_definition" {
  family       = "${var.project_name}-frontend-task-definition"
  memory       = 20 # in megabytes
  network_mode = "bridge"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name : "frontend-server"
      image : "nginx"
      portMappings : [
        {
          appProtocol : "http"
          containerPort : 80
          hostPort : 8000
        }
      ]
      logConfiguration : {
        logDriver : "awslogs"
        options : {
          awslogs-create-group : "true"
          awslogs-region : local.region
          awslogs-group : "${var.project_name}-log-group"
          awslogs-stream-prefix : "frontend"
          mode : "non-blocking"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "backend_task_definition" {
  family       = "${var.project_name}-backend-task-definition"
  memory       = 60 # in megabytes
  network_mode = "bridge"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name : "backend-server"
      image : "httpd"
      portMappings : [
        {
          appProtocol : "http"
          containerPort : 80
          hostPort : 8001
        }
      ]
      logConfiguration : {
        logDriver : "awslogs"
        options : {
          awslogs-create-group : "true"
          awslogs-region : local.region
          awslogs-group : "${var.project_name}-log-group"
          awslogs-stream-prefix : "backend"
          mode : "non-blocking"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "job_task_definition" {
  family       = "${var.project_name}-job-task-definition"
  memory       = 10 # in megabytes
  network_mode = "none"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name : "job-server"
      image : "hello-world"
      logConfiguration : {
        logDriver : "awslogs"
        options : {
          awslogs-create-group : "true"
          awslogs-region : local.region
          awslogs-group : "${var.project_name}-log-group"
          awslogs-stream-prefix : "job"
          mode : "non-blocking"
        }
      }
    }
  ])
}

##
## ECS Services
##
resource "aws_ecs_service" "frontend_service" {
  name    = "${var.project_name}-frontend-service"
  cluster = aws_ecs_cluster.ecs_cluster.arn
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    base              = 0
    weight            = 1
  }
  desired_count   = 1
  task_definition = aws_ecs_task_definition.frontend_task_definition.arn
}

resource "aws_ecs_service" "backend_service" {
  name    = "${var.project_name}-backend-service"
  cluster = aws_ecs_cluster.ecs_cluster.arn
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    base              = 0
    weight            = 1
  }
  desired_count   = 1
  task_definition = aws_ecs_task_definition.backend_task_definition.arn
}

##
## ECS Tasks
##
resource "aws_iam_role" "job_schedule_iam_role" {
  name = "${var.project_name}-job-schedule-iam-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "sts:AssumeRole"
        ]
        Condition : {
          StringEquals : {
            "aws:SourceAccount" : local.account_id
          }
        }
        Principal : {
          Service : [
            "scheduler.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "job_schedule_iam_policy" {
  name = "${var.project_name}-job-schedule-iam-policy"
  policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "ecs:RunTask"
        ]
        Resource : [
          "${aws_ecs_task_definition.job_task_definition.arn_without_revision}:*"
        ]
        Condition : {
          ArnLike : {
            "ecs:cluster" : aws_ecs_cluster.ecs_cluster.arn
          }
        }
      },
      {
        Effect : "Allow"
        Action : "iam:PassRole"
        Resource : [
          "*"
        ]
        Condition : {
          StringLike : {
            "iam:PassedToService" : "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "job_schedule_policy_attachment" {
  role       = aws_iam_role.job_schedule_iam_role.name
  policy_arn = aws_iam_policy.job_schedule_iam_policy.arn
}

resource "aws_scheduler_schedule" "job_schedule" {
  name = "${var.project_name}-job-schedule"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression_timezone = "America/Porto_Velho"
  schedule_expression          = "rate(10 minutes)"
  target {
    arn      = aws_ecs_cluster.ecs_cluster.arn
    role_arn = aws_iam_role.job_schedule_iam_role.arn
    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.job_task_definition.arn
      capacity_provider_strategy {
        capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
        base              = 0
        weight            = 1
      }
      task_count = 1
    }
  }
}
