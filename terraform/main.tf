locals {
  cluster_name = "${var.project_name}-${var.environment}"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  cluster_name       = local.cluster_name
  tags              = local.tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  eks_version        = var.eks_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  tags = local.tags
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-app"
  tags           = local.tags
}
