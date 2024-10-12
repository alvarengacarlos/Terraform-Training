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
## VPC, Internet Gateway, Subnet, Route Table
##
resource "aws_vpc" "vpc" {
  cidr_block       = "172.16.0.0/28"
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

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "172.16.0.0/28"
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
  vpc_id = aws_vpc.vpc.id
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
resource "aws_security_group" "server_sg" {
  name        = "${var.project_name}-server-sg"
  description = "For server instance"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "server_sg_allow_http" {
  security_group_id = aws_security_group.server_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port = 80
  to_port = 80
}

resource "aws_vpc_security_group_ingress_rule" "server_sg_allow_https" {
  security_group_id = aws_security_group.server_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port = 443
  to_port = 443
}

resource "aws_vpc_security_group_egress_rule" "server_sg_allow_all" {
  security_group_id = aws_security_group.server_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

##
## Instances, Roles, Elastic IP
##
resource "aws_iam_role" "sever_iam_role" {
  name = "${var.project_name}-server-iam-role"
  description = "Allows EC2 Instance to be accessed through Session Manager"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Principal": {
          "Service": [
            "ec2.amazonaws.com"
          ]
        }
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "server_iam_instance_profile" {
  name = "${var.project_name}-server-iam-instance-profile"
  role = aws_iam_role.sever_iam_role.id
}

resource "aws_instance" "server" {
  ami           = "ami-0fff1b9a61dec8a5f"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.server_sg.id]
  subnet_id = aws_subnet.public_subnet.id
  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }
  iam_instance_profile = aws_iam_instance_profile.server_iam_instance_profile.id
  user_data = var.server_user_data

  tags = {
    Name = "${var.project_name}-server"
  }
}

resource "aws_eip" "eip" {
  domain   = "vpc"
  instance = aws_instance.server.id
  tags = {
    Name = "${var.project_name}-eip"
  }
  depends_on = [aws_internet_gateway.ig]
}
