#!/bin/bash

# Set AWS region and VPC ID (modify these accordingly)
AWS_REGION="us-east-1"
VPC_ID="vpc-7aa76207"
EKS_CLUSTER_NAME="movie-pipeline-cluster"
NODE_GROUP_NAME="movie-pipeline-nodes"
ECR_REPO_NAME="movie-pipeline-app"
IAM_CLUSTER_ROLE="movie-pipeline-eks-cluster-role"
IAM_NODE_GROUP_ROLE="movie-pipeline-node-group"
GITHUB_USER="movie-pipeline-github-actions"

echo "🔍 Verifying AWS Resources in $AWS_REGION..."
echo "---------------------------------------------"

### ✅ Check if the Internet Gateway (IGW) is attached ###
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[*].InternetGatewayId" --output text)
if [[ -z "$IGW_ID" ]]; then
    echo "❌ Internet Gateway is NOT attached to VPC $VPC_ID!"
else
    echo "✅ Internet Gateway found: $IGW_ID"
fi

### ✅ Verify Subnets exist in VPC ###
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)
if [[ -z "$SUBNETS" ]]; then
    echo "❌ No subnets found in VPC $VPC_ID!"
else
    echo "✅ Subnets found in VPC: $SUBNETS"
fi

### ✅ Check if the EKS Cluster exists and is ACTIVE ###
CLUSTER_STATUS=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query "cluster.status" --output text 2>/dev/null)
if [[ "$CLUSTER_STATUS" == "ACTIVE" ]]; then
    echo "✅ EKS Cluster '$EKS_CLUSTER_NAME' is ACTIVE"
else
    echo "❌ EKS Cluster '$EKS_CLUSTER_NAME' is NOT active or does not exist!"
fi

### ✅ Check if Node Group is ACTIVE ###
NODE_GROUP_STATUS=$(aws eks describe-nodegroup --cluster-name "$EKS_CLUSTER_NAME" --nodegroup-name "$NODE_GROUP_NAME" --query "nodegroup.status" --output text 2>/dev/null)
if [[ "$NODE_GROUP_STATUS" == "ACTIVE" ]]; then
    echo "✅ EKS Node Group '$NODE_GROUP_NAME' is ACTIVE"
else
    echo "❌ EKS Node Group '$NODE_GROUP_NAME' is NOT active or does not exist!"
fi

### ✅ Check if Nodes joined the EKS Cluster ###
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [[ "$NODE_COUNT" -gt 0 ]]; then
    echo "✅ $NODE_COUNT Nodes have successfully joined the EKS Cluster"
else
    echo "❌ No nodes found in the cluster! Check IAM roles & instance configurations."
fi

### ✅ Verify IAM Roles have Correct Policies Attached ###
function check_iam_policies() {
    ROLE_NAME=$1
    REQUIRED_POLICIES=("${@:2}")

    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[*].PolicyName" --output text)

    for policy in "${REQUIRED_POLICIES[@]}"; do
        if echo "$ATTACHED_POLICIES" | grep -q "$policy"; then
            echo "✅ $policy is attached to $ROLE_NAME"
        else
            echo "❌ MISSING: $policy is NOT attached to $ROLE_NAME"
        fi
    done
}

echo "🔎 Checking IAM Policies for EKS Cluster Role..."
check_iam_policies "$IAM_CLUSTER_ROLE" "AmazonEKSClusterPolicy" "AmazonEKSServicePolicy"

echo "🔎 Checking IAM Policies for Node Group Role..."
check_iam_policies "$IAM_NODE_GROUP_ROLE" "AmazonEKSWorkerNodePolicy" "AmazonEKS_CNI_Policy" "AmazonEC2ContainerRegistryPowerUser" "AmazonSSMManagedInstanceCore"

### ✅ Verify ECR Repository Exists ###
ECR_REPO_STATUS=$(aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --query "repositories[*].repositoryName" --output text 2>/dev/null)
if [[ "$ECR_REPO_STATUS" == "$ECR_REPO_NAME" ]]; then
    echo "✅ ECR Repository '$ECR_REPO_NAME' exists"
else
    echo "❌ ECR Repository '$ECR_REPO_NAME' NOT found!"
fi

### ✅ Test ECR Authentication ###
ECR_LOGIN=$(aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" 2>/dev/null)
if [[ $? -eq 0 ]]; then
    echo "✅ Successfully authenticated to ECR"
else
    echo "❌ ECR Authentication failed! Check IAM permissions."
fi

echo "---------------------------------------------"
echo "🎉 Verification complete!"