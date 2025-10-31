resource "aws_security_group" "web_server_security_group" {
  name        = "air-chain-web-server-security-group"
  description = "Security Group for the web server"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "http_ingress_rule_for_web_server_security_group" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh_ingress_rule_for_web_server_security_group" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = var.my_public_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_egress_rule_for_web_server_security_group" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_iam_role" "web_server_service_role" {
  name = "air-chain-web-server-service-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Principal : {
          Service : "ec2.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "s3_role_policy_attachment_for_web_server" {
  role       = aws_iam_role.web_server_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloud_watch_agent_role_policy_attachment_for_web_server" {
  role       = aws_iam_role.web_server_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloud_watch_logs_role_policy_attachment_for_web_server" {
  role       = aws_iam_role.web_server_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_role_policy_attachment_for_web_server" {
  role       = aws_iam_role.web_server_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_policy_attachment_for_web_server" {
  role       = aws_iam_role.web_server_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployReadOnlyAccess"
}

resource "aws_iam_role_policy" "role_policy_for_web_server" {
  name = "air-chain-kms-role-policy-for-web-server"
  role = aws_iam_role.web_server_service_role.id
  policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource : [
          "arn:aws:kms:${var.aws_region}:${local.account_id}:key/*",
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "web_server_instance_profile" {
  name = "air-chain-web-server-instance-profile"
  role = aws_iam_role.web_server_service_role.name
}

resource "aws_instance" "web_server" {
  ami                    = "ami-0df8c184d5f6ae949"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_server_security_group.id]
  subnet_id              = aws_subnet.public_subnet_1.id
  iam_instance_profile   = aws_iam_instance_profile.web_server_instance_profile.name
  availability_zone      = local.availability_zone
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 10
    volume_type           = "gp2"
  }
  key_name = "air-chain-web-server-key-pair"

  tags = {
    Name        = "air-chain-web-server"
    Environment = var.environment
  }
  user_data = <<EOF
#!/bin/bash
echo "Updating and Upgrading..."
yum update
yum upgrade -y

cd /root

echo "Installing packages..."
yum install -y java-23-amazon-corretto ruby wget nginx amazon-cloudwatch-agent jq

wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

wget https://aws-codedeploy-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/install
chmod +x ./install
./install auto

wget https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/11.2.0/flyway-commandline-11.2.0-linux-x64.tar.gz
tar -xzf flyway-commandline-11.2.0-linux-x64.tar.gz
ln -s `pwd`/flyway-11.2.0/flyway /usr/local/bin

wget https://dev.mysql.com/get/mysql84-community-release-el9-1.noarch.rpm
yum localinstall -y mysql84-community-release-el9-1.noarch.rpm
yum update
yum install -y mysql-connector-j mysql-community-client

echo "Starting services..."
systemctl start nginx
systemctl enable nginx
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

echo "Configuring services..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
mkdir /srv/www
mkdir /srv/air-chain-services
EOF
}

resource "aws_security_group" "database_server_security_group" {
  name        = "air-chain-database-server-security-group"
  description = "Security Group for the database server"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_ingress_rule_for_database_server_security_group" {
  security_group_id            = aws_security_group.database_server_security_group.id
  referenced_security_group_id = aws_security_group.web_server_security_group.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_db_subnet_group" "database_server_subnet_group" {
  name = "air-chain-database-server-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  tags = {
    Environment = var.environment
  }
}

resource "aws_db_instance" "database_server" {
  allocated_storage          = 20
  auto_minor_version_upgrade = true
  availability_zone          = local.availability_zone
  backup_retention_period    = 7
  backup_window              = "00:00-01:00"
  db_name                    = "air_chain_backend_db"
  db_subnet_group_name       = aws_db_subnet_group.database_server_subnet_group.name
  engine                     = "mysql"
  engine_version             = "8.4.3"
  engine_lifecycle_support   = "open-source-rds-extended-support-disabled"
  identifier                 = "air-chain-database-server"
  instance_class             = "db.t3.micro"
  maintenance_window         = "Mon:01:00-Mon:02:00"
  max_allocated_storage      = 0
  network_type               = "IPV4"
  password                   = var.database_root_user_password
  port                       = 3306
  skip_final_snapshot        = true
  storage_type               = "gp2"
  username                   = "root"
  vpc_security_group_ids = [
    aws_security_group.database_server_security_group.id
  ]
  tags = {
    Environment = var.environment
  }
}