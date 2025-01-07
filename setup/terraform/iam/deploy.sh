#!/bin/bash

ENVIRONMENT_NAME="movie-pipeline"
REGION="us-east-1"  # Change to your region

# Deploy IAM resources first
echo "Deploying IAM resources..."
terraform init
terraform apply -auto-approve

# Store IAM outputs
EKS_CLUSTER_ROLE_ARN=$(terraform output -raw eks_cluster_role_arn)
NODE_GROUP_ROLE_ARN=$(terraform output -raw node_group_role_arn)
GITHUB_ACCESS_KEY=$(terraform output -raw github_action_access_key)
GITHUB_SECRET_KEY=$(terraform output -raw github_action_secret_key)