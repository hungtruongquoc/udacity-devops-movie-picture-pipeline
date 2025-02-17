###################
# Variable Configuration
###################

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
  default     = "1.31"
}

###################
# Provider Configuration
###################

provider "aws" {
  region = var.region
}

###################
# Networking (IGW, Subnets & Routing)
###################

resource "aws_internet_gateway" "igw" {
  vpc_id = var.existing_vpc_id
  tags   = { Name = "${var.environment_name}-internet-gateway" }
}

resource "aws_route_table" "public" {
  vpc_id = var.existing_vpc_id
  tags   = { Name = "${var.environment_name}-public-route-table" }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  depends_on             = [aws_internet_gateway.igw]
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = var.existing_vpc_id
  cidr_block              = "172.31.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                          = "${var.environment_name}-public-subnet-1"
    "kubernetes.io/role/elb"      = "1"
    "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = var.existing_vpc_id
  cidr_block              = "172.31.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                          = "${var.environment_name}-public-subnet-2"
    "kubernetes.io/role/elb"      = "1"
    "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

###################
# IAM Roles
###################

data "aws_iam_role" "eks_cluster" { name = "${var.environment_name}-eks-cluster-role" }
data "aws_iam_role" "node_group" { name = "${var.environment_name}-node-group" }

resource "aws_ecr_repository" "ecr_app" {
  name                 = "${var.environment_name}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

###################
# Fetch EKS Recommended AMI Version
###################

data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${var.k8s_version}/amazon-linux-2/recommended/release_version"
  depends_on = [aws_eks_cluster.main]
}

###################
# EKS Cluster
###################

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

###################
# EKS Node Group
###################

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

  tags = { Name = "${var.environment_name}-node-group-sg" }
}

resource "aws_eks_node_group" "main" {
  node_group_name = "${var.environment_name}-nodes"
  cluster_name    = aws_eks_cluster.main.name
  node_role_arn   = data.aws_iam_role.node_group.arn
  subnet_ids      = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  instance_types  = ["t3.medium"]
  ami_type        = "AL2_x86_64"
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.main]
}

###################
# Outputs
###################

output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_name" { value = aws_eks_cluster.main.name }
output "internet_gateway_id" { value = aws_internet_gateway.igw.id }
output "public_route_table_id" { value = aws_route_table.public.id }

output "ecr_repository_url" {
  value = aws_ecr_repository.ecr_app.repository_url
}