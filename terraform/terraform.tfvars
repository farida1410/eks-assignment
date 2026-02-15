aws_region     = "us-east-1"
environment    = "dev"
project_name   = "eks-assignment"
vpc_cidr       = "10.0.0.0/16"
eks_version    = "1.28"

availability_zones = ["us-east-1a", "us-east-1b"]

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 4
