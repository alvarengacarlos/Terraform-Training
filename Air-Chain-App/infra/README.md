# Infra
## Description
...

## Requirements
- Terraform 1.10.4
- AWS CLI 2.23.2
- jq 1.7.1

## Provisioning
> **Warning:** All next commands expect you to be inside `infra` directory.

Before provisioning you need configure a `GitHub Fine-grained personal access token` to allow AWS access your repository.
The necessary permissions for the token can be found in [AWS Documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/access-tokens-github.html).

Set the GitHub personal access token:
```bash
GITHUB_PERSONAL_ACCESS_TOKEN="your personal access token"
```

Create the key pair:
```bash
aws ec2 create-key-pair \
    --key-name air-chain-web-server-key-pair \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --output text > air-chain-web-server-key-pair.pem
    
chmod 400 air-chain-web-server-key-pair.pem
```

Set the `DATABASE_ROOT_USER_PASSWORD` variable:

> **Warning:** Cannot contain the /, ', " or @ characters. 

```bash
DATABASE_ROOT_USER_PASSWORD="your database root user password"
```

Set the `MY_PUBLIC_IP` variable:
```bash
MY_PUBLIC_IP=$(host -4 myip.opendns.com resolver1.opendns.com | grep "myip.opendns.com has" | awk '{print $4}')
```

Initialize the directory:
```bash
terraform init
```

Create the infrastructure:

> **Warning:** You can set `dev` or `prod` for `environment` variable and
> `us-east-1` and `us-east-2` for `aws_region` variable.

```bash
terraform apply \
-var="environment=dev" \
-var="my_public_ip=$MY_PUBLIC_IP/32" \
-var="aws_region=us-east-1" \
-var="database_root_user_password=$DATABASE_ROOT_USER_PASSWORD" \
-var="github_personal_access_token=$GITHUB_PERSONAL_ACCESS_TOKEN"
```

Save your `terraform.tfstate` file securely.

> **Carefully:** The `terraform.tfstate` file contains sensitive information. 

Set the `AIR_CHAIN_WEB_SERVER_PUBLIC_IP` variable:
```bash
AIR_CHAIN_WEB_SERVER_PUBLIC_IP=$(aws ec2 describe-instances --filter "Name=tag-key,Values=Name" "Name=tag-value,Values=air-chain-web-server" | jq -csr '.[0].Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicIp')
```

SSH the air chain web server machine:
```bash
ssh -i "air-chain-web-server-key-pair.pem" ec2-user@$AIR_CHAIN_WEB_SERVER_PUBLIC_IP
```

### Configuring Air Chain Services
Create the backend systemd service in the file `/etc/systemd/system/air-chain-backend.service` as root and input this:
```text
[Unit]
Description=Manage the air chain backend web service that runs on 8080 port by default
After=multi-user.target

[Service]
ExecStart=java -jar /srv/air-chain-services/backend.jar
Type=exec

[Install]
WantedBy=multi-user.target
```

Active the systemd service:
```bash
sudo systemctl daemon-reload

sudo systemctl enable air-chain-backend
```

### Configuring Nginx
> **Warning:** In the next step change only the `server` block

Open the `/etc/nginx/nginx.conf` file as root and input this:
```text
...
server {
    listen 80;
    location / {
        root /srv/www;
    }
    location /backend/ {
		proxy_pass http://localhost:8080/;
	}
}
...
```

Restart the service:
```bash
sudo nginx -s reload
```

Close SSH:
```bash
exit
```

### Creating artifacts
Create the frontend and backend artifacts:
```bash
aws codebuild start-build --project-name air-chain-codebuild-project
```

### Creating deployments
Create frontend deployment:
```bash
aws deploy create-deployment --application-name air-chain-frontend-codedeploy-app --deployment-group-name air-chain-frontend-codedeploy-deployment-group --s3-location bucket=air-chain-pipeline-bucket,bundleType=tgz,key=air-chain-codebuild-project/frontend.tar.gz
```

Create backend deployment:
```bash
aws deploy create-deployment --application-name air-chain-backend-codedeploy-app --deployment-group-name air-chain-backend-codedeploy-deployment-group --s3-location bucket=air-chain-pipeline-bucket,bundleType=tgz,key=air-chain-codebuild-project/backend.tar.gz
```

> **Tip:** You can access the logs using this command: `cat /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log`.

Now you have two web services exposed to the internet. They can be accessed through the following PATHs:

| PATH       | Web Service | curl command to test                                                                                     |
|------------|-------------|----------------------------------------------------------------------------------------------------------|
| /          | Frontend    | curl -X GET http://$AIR_CHAIN_WEB_SERVER_PUBLIC_IP/                                                      |
| /backend/* | Backend     | curl -X GET -H "Content-Type: application/json" http://$AIR_CHAIN_WEB_SERVER_PUBLIC_IP/backend/histories |

## Destroying 
Remove resources provisioned by Terraform:
```bash
terraform destroy \
-var="environment=dev" \
-var="my_public_ip=$MY_PUBLIC_IP/32" \
-var="aws_region=us-east-1" \
-var="database_root_user_password=null" \
-var="github_personal_access_token=null"
```

Remove key pair:
```bash
aws ec2 delete-key-pair --key-name air-chain-web-server-key-pair

rm air-chain-web-server-key-pair.pem
```
