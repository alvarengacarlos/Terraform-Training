#!/bin/bash

DB_USER=root
DB_NAME=air_chain_backend_db
DB_PASSWORD=$(aws ssm get-parameter --with-decryption --name /dev/air-chain/database/root-password | jq -r .Parameter.Value)
DB_ENDPOINT=$(aws ssm get-parameter --name /dev/air-chain/database/endpoint | jq -r .Parameter.Value)

DEPLOYMENT_GROUP=$(aws deploy get-deployment-group --application-name air-chain-backend-codedeploy-app --deployment-group-name air-chain-backend-codedeploy-deployment-group)
DEPLOYMENT_GROUP_ID=$(echo $DEPLOYMENT_GROUP | jq -r .deploymentGroupInfo.deploymentGroupId)
CURRENT_DEPLOYMENT=$(echo $DEPLOYMENT_GROUP | jq -r .deploymentGroupInfo.lastAttemptedDeployment.deploymentId)
MIGRATIONS_DIR=/opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$CURRENT_DEPLOYMENT/deployment-archive/migrations/

echo "Applying migrations"
flyway -url="jdbc:mysql://$DB_ENDPOINT/$DB_NAME?user=$DB_USER&password=$DB_PASSWORD" -locations="filesystem:$MIGRATIONS_DIR" migrate
