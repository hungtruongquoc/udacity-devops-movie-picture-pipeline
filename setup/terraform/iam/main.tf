# iam/main.tf

variable "environment_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "movie-pipeline"
}

provider "aws" {
  region = "us-east-1"
}

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.environment_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Node Group Role
resource "aws_iam_role" "node_group" {
  name = "${var.environment_name}-node-group"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_group_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# GitHub Actions User
resource "aws_iam_user" "github_action_user" {
  name = "${var.environment_name}-github-actions"
}

resource "aws_iam_user_policy" "github_action_user_permission" {
  name = "${var.environment_name}-github-actions-policy"
  user = aws_iam_user.github_action_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "github_action_user" {
  user = aws_iam_user.github_action_user.name
}

# Outputs
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group.arn
}

output "github_action_access_key" {
  value = aws_iam_access_key.github_action_user.id
}

output "github_action_secret_key" {
  value     = aws_iam_access_key.github_action_user.secret
  sensitive = true
}