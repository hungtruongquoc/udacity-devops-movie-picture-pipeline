#!/bin/bash
ENVIRONMENT_NAME="movie-pipeline"
REGION="us-east-1"

# Deploy infrastructure
echo "Deploying infrastructure..."
terraform init
terraform apply -auto-approve

# Get infrastructure outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
ECR_REPO_URL_FRONTEND=$(terraform output -raw ecr_repository_url_frontend)
ECR_REPO_URL_BACKEND=$(terraform output -raw ecr_repository_url_backend)

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Create base64 encoded kubeconfig for GitHub secrets
KUBE_CONFIG_DATA=$(cat ~/.kube/config | base64)

echo "Deployment complete! Use these values for GitHub Actions secrets:"
echo "AWS_REGION: ${REGION}"
echo "KUBE_CONFIG_DATA: ${KUBE_CONFIG_DATA}"
echo "ECR_REPOSITORY_URL: ${ECR_REPO_URL}"
echo "CLUSTER_ENDPOINT: ${CLUSTER_ENDPOINT}"
echo "ECR_REPO_URL_FRONTEND: ${ECR_REPO_URL_FRONTEND}"
echo "ECR_REPO_URL_BACKEND: ${ECR_REPO_URL_BACKEND}"
