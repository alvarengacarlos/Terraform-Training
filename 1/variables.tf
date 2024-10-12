variable "project_name" {
  description = "Used to set the project name"
  type = string
  nullable = false
}

variable "server_user_data" {
  description = "The EC2 instance frontend server user data"
  type        = string
  default     = <<EOF
#!/bin/bash
echo "Updating and installing packages"
yum update -y
yum upgrade -y
yum install git docker -y

echo "Enabling and starting 'Docker' service"
systemctl enable docker
systemctl start docker

echo "Creating and running a 'webserver' container"
docker container run --detach --name webserver --publish 80:80 nginx
EOF
}
