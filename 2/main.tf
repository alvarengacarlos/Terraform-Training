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

##
## VPC, Internet Gateway, NatGateway, Subnet, Route Table, Elastic IP
##
resource "aws_vpc" "vpc" {
  cidr_block       = "172.16.0.0/24"
  instance_tenancy = "default"

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

resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "172.16.0.0/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.project_name}-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "172.16.0.32/27"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.project_name}-public-subnet-2"
  }
}

resource "aws_eip" "eip_1" {
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip-1"
  }

  depends_on = [aws_internet_gateway.ig]
}

resource "aws_nat_gateway" "public_nat_gateway_1" {
  allocation_id = aws_eip.eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "${var.project_name}-public-nat-gateway-1"
  }

  depends_on = [aws_internet_gateway.ig]
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "172.16.0.64/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "172.16.0.96/27"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.project_name}-private-subnet-2"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  route {
    cidr_block = "172.16.0.0/24"
    gateway_id = "local"
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "172.16.0.0/24"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.public_nat_gateway_1.id
  }

  tags = {
    Name = "${var.project_name}-private-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_1_route_table_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_route_table_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_1_route_table_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_route_table_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

##
## Nacl
##
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

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

resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

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
    Name = "${var.project_name}-private-nacl"
  }
}

##
## Security Group
##
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "For ALB"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_egress_rule" "alb_sg_allow_http_from_frontend_sg" {
  security_group_id = aws_security_group.alb_sg.id
  referenced_security_group_id = aws_security_group.frontend_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_sg_allow_http_from_backend_sg" {
  security_group_id = aws_security_group.alb_sg.id
  referenced_security_group_id = aws_security_group.backend_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_sg_allow_http" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_sg_allow_https" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
}

resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-frontend-sg"
  description = "For frontend server instances"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "frontend_sg_allow_http" {
  security_group_id = aws_security_group.frontend_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "frontend_sg_allow_all" {
  security_group_id = aws_security_group.frontend_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "For backend server instances"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "backend_sg_allow_http" {
  security_group_id = aws_security_group.backend_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_sg_allow_all" {
  security_group_id = aws_security_group.backend_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

##
## ALB
##
resource "aws_lb" "alb" {
  name = "${var.project_name}-alb"
  security_groups = [
    aws_security_group.alb_sg.id
  ]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

##
## Self signed certificate with ACM
##
resource "tls_private_key" "tls_prk" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_self_signed_cert" "alb_tls_certificate" {
  private_key_pem       = tls_private_key.tls_prk.private_key_pem

  subject {
    country = "BR"
    locality = "Ariquemes"
    common_name = aws_lb.alb.dns_name
    organization = var.project_name
  }

  validity_period_hours = 8760 # one year in hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  depends_on = [aws_lb.alb]
}

resource "aws_acm_certificate" "alb_tls_certificate" {
  private_key = tls_private_key.tls_prk.private_key_pem
  certificate_body = tls_self_signed_cert.alb_tls_certificate.cert_pem
}

##
## ALB target group
##
resource "aws_lb_target_group" "frontend_server_tg" {
  name = "${var.project_name}-frontend-server-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_lb_target_group" "backend_server_tg" {
  name = "${var.project_name}-backend-server-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc.id
}

##
## ALB listener
##
resource "aws_lb_listener" "https_alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = aws_acm_certificate.alb_tls_certificate.arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.frontend_server_tg.arn
  }
}

resource "aws_lb_listener_rule" "forward_to_backend_tg_alb_listener_rule" {
  listener_arn = aws_lb_listener.https_alb_listener.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.backend_server_tg.arn
  }

  condition {
    path_pattern {
      values = [
        "/api",
        "/api/*"
      ]
    }
  }

  tags = {
    Name = "${var.project_name}-forward-to-backend-tg-alb-listener-rule"
  }
}

##
## Launch Templates
##
resource "aws_launch_template" "backend_launch_template" {
  name = "${var.project_name}-backend-launch-template"
  image_id = "ami-0fff1b9a61dec8a5f"
  instance_type = "t2.micro"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
      volume_size = 8
      delete_on_termination = true
      encrypted = false
    }
  }
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data = base64encode(var.backend_server_user_data)
  default_version = 1
}

resource "aws_launch_template" "frontend_launch_template" {
  name = "${var.project_name}-frontend-launch-template"
  image_id = "ami-0fff1b9a61dec8a5f"
  instance_type = "t2.micro"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
      volume_size = 8
      delete_on_termination = true
      encrypted = false
    }
  }
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  user_data = base64encode(var.frontend_server_user_data)
  default_version = 1
}

##
## Auto Scaling Group
##
resource "aws_autoscaling_group" "backend_asg" {
  name = "${var.project_name}-backend-asg"
  launch_template {
    id = aws_launch_template.backend_launch_template.id
    version = aws_launch_template.backend_launch_template.default_version
  }
  vpc_zone_identifier = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  target_group_arns = [aws_lb_target_group.backend_server_tg.arn]
  health_check_grace_period = 240 # 4 minutes in seconds
  health_check_type = "ELB"
  min_size = 1
  desired_capacity = 2
  max_size = 6
}

resource "aws_autoscaling_policy" "backend_asg_policy" {
  name                   = "${var.project_name}-backend-asg-policy"
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}

resource "aws_autoscaling_group" "frontend_asg" {
  name = "${var.project_name}-frontend-asg"
  launch_template {
    id = aws_launch_template.frontend_launch_template.id
    version = aws_launch_template.frontend_launch_template.default_version
  }
  vpc_zone_identifier = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  target_group_arns = [aws_lb_target_group.frontend_server_tg.arn]
  health_check_grace_period = 240 # 4 minutes in seconds
  health_check_type = "ELB"
  min_size = 1
  desired_capacity = 2
  max_size = 4
}

resource "aws_autoscaling_policy" "frontend_asg_policy" {
  name                   = "${var.project_name}-frontend-asg-policy"
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
}
