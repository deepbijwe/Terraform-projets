variable "project_name" {
  description = "Project name used as prefix for all resources"
  default     = "eks-dev"
}

variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets (EKS nodes live here)"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  default     = "c7i-flex.large"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  default     = 2
}
