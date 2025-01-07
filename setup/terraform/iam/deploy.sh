#!/bin/bash

ENVIRONMENT_NAME="movie-pipeline"
REGION="us-east-1"  # Change to your region

# Deploy IAM resources first
echo "Deploying IAM resources..."
terraform init
terraform apply -auto-approve

# Store IAM outputs
GITHUB_ACCESS_KEY=$(terraform output -raw github_action_access_key)
GITHUB_SECRET_KEY=$(terraform output -raw github_action_secret_key)

echo "Deployment complete! Use these values for GitHub Actions secrets:"
echo "AWS_ACCESS_KEY_ID: ${GITHUB_ACCESS_KEY}"
echo "AWS_SECRET_ACCESS_KEY: ${GITHUB_SECRET_KEY}"
echo "AWS_REGION: ${REGION}"