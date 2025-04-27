# General
variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}

# EKS Cluster
variable "cluster_name" {
  description = "Name of the EKS cluster"
  default     = "demo-eks"
}

variable "node_group_name" {
  description = "Name for the EKS worker node group"
  default     = "demo-eks-node-group"
}

variable "key_name" {
  description = "Name for the SSH key pair"
  default     = "demo-eks-key"
}

variable "private_key_path" {
  description = "Local path to save the SSH private key"
  default     = "/tmp/node-key.pem"
}

variable "instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  default     = 3
}

# Jenkins EC2 Instance
variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  default     = "t2.medium"
}
