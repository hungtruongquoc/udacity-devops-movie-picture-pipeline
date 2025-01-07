# infrastructure/main.tf

variable "environment_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "movie-pipeline"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "existing_vpc_id" {
  description = "ID of existing VPC"
  type        = string
  default     = "vpc-7aa76207"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.24"
}

# Data sources for IAM roles
data "aws_iam_role" "eks_cluster" {
  name = "${var.environment_name}-eks-cluster-role"
}

data "aws_iam_role" "node_group" {
  name = "${var.environment_name}-node-group"
}

provider "aws" {
  region = var.region
}

###################
# ECR Repositories
###################
resource "aws_ecr_repository" "ecr_app" {
  name                 = "${var.environment_name}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Subnet Resources
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = var.existing_vpc_id
  cidr_block              = "172.31.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${var.environment_name}-public-subnet-1"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = var.existing_vpc_id
  cidr_block              = "172.31.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${var.environment_name}-public-subnet-2"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.environment_name}-cluster"
  version  = var.k8s_version
  role_arn = data.aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }
}

# EKS Node Group
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.main.version}/amazon-linux-2/recommended/release_version"
}

resource "aws_security_group" "node_group_sg" {
  name        = "eks-node-group-sg"
  description = "Security group for EKS node group"
  vpc_id      = var.existing_vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-node-group-sg"
  }
}

resource "aws_eks_node_group" "main" {
  node_group_name = "${var.environment_name}-nodes"
  cluster_name    = aws_eks_cluster.main.name
  node_role_arn   = data.aws_iam_role.node_group.arn
  subnet_ids      = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  instance_types  = ["t3.medium"]  # Use medium instead of small

  # Add this line
  remote_access {
    ec2_ssh_key = "your-key-pair-name"  # Optional: for debugging
    source_security_group_ids = [aws_security_group.node_group_sg.id]
  }

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  # Add this to ensure proper network setup time
  depends_on = [
    aws_eks_cluster.main
  ]

  # Optional: Add launch template with more settings
  launch_template {
    name    = "${var.environment_name}-launch-template"
    version = "1"
  }
}

# Add launch template
resource "aws_launch_template" "eks_node" {
  name = "${var.environment_name}-launch-template"

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.node_group_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.environment_name}-node"
    }
  }
}

# Outputs
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ecr_app.repository_url
}