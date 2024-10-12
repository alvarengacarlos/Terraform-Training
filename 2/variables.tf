variable "project_name" {
  description = "Used to set the project name"
  type = string
  nullable = false
}

variable "frontend_server_user_data" {
  description = "The EC2 instance frontend server user data"
  type        = string
  default     = <<EOF
#!/bin/bash
echo "Installing packages"
yum update -y
yum upgrade -y
yum install git nodejs nginx -y

echo "Creating simple index.html"
echo "<h1>Hello there!</h1>" > index.html

echo "Configuring nginx server"
mkdir -p /srv/ui
cp index.html /srv/ui/

cat <<EOL > /etc/nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    server {
        location / {
                root /srv/ui;
        }
    }
}
EOL

echo "Starting server"
systemctl enable nginx
systemctl start nginx
EOF
}

variable "backend_server_user_data" {
  description = "The EC2 instance backend server user data"
  type = string
  default = <<EOF
#!/bin/bash
echo "Installing packages"
yum update -y
yum upgrade -y
yum install git zip java-22-amazon-corretto -y

cd /srv
curl https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip --output apache-maven-3.9.9-bin.zip
unzip apache-maven-3.9.9-bin.zip

echo "Cloning repository"
git clone https://github.com/openliberty/guide-getting-started.git
cd guide-getting-started/finish
echo "Changing port from 9080 to 80"
sed -i 's/<liberty.var.http.port>9080<\/liberty.var.http.port>/<liberty.var.http.port>80<\/liberty.var.http.port>/' pom.xml

echo "Preparing and starting server"
/srv/apache-maven-3.9.9/bin/mvn compile
/srv/apache-maven-3.9.9/bin/mvn liberty:create
/srv/apache-maven-3.9.9/bin/mvn liberty:install-feature
/srv/apache-maven-3.9.9/bin/mvn liberty:deploy
/srv/apache-maven-3.9.9/bin/mvn liberty:start
EOF
}