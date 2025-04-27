#####################
# VPC and Subnets
#####################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  worker_subnet_ids = [
    for s in data.aws_subnet.default :
    s.id if s.availability_zone != "us-east-1e"
  ]
}

#####################
# EKS Cluster
#####################

resource "aws_iam_role" "eksClusterRole" {
  name = "eksClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eksClusterPolicy" {
  role       = aws_iam_role.eksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eksServicePolicy" {
  role       = aws_iam_role.eksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_eks_cluster" "demo" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eksClusterRole.arn

  vpc_config {
    subnet_ids = local.worker_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eksClusterPolicy,
    aws_iam_role_policy_attachment.eksServicePolicy
  ]
}

#####################
# Worker Node Group
#####################

resource "tls_private_key" "node_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "node_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.node_key.public_key_openssh
}

resource "local_file" "private_key_file" {
  content         = tls_private_key.node_key.private_key_pem
  filename        = var.private_key_path
  file_permission = "0600"
}

resource "aws_cloudformation_stack" "node_group_stack" {
  name         = "${var.cluster_name}-nodegroup"
  template_url = "https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml"

  parameters = {
    ClusterName                         = aws_eks_cluster.demo.name
    NodeGroupName                       = var.node_group_name
    NodeAutoScalingGroupMinSize         = tostring(var.min_size)
    NodeAutoScalingGroupDesiredCapacity = tostring(var.desired_size)
    NodeAutoScalingGroupMaxSize         = tostring(var.max_size)
    NodeInstanceType                    = var.instance_type
    KeyName                             = aws_key_pair.node_key_pair.key_name
    VpcId                               = data.aws_vpc.default.id
    Subnets                             = join(",", local.worker_subnet_ids)
    ClusterControlPlaneSecurityGroup    = aws_eks_cluster.demo.vpc_config[0].cluster_security_group_id
    NodeVolumeSize                      = "20"
  }

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  depends_on = [
    aws_eks_cluster.demo
  ]
}

#####################
# Jenkins EC2 Setup
#####################

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name   = "jenkins-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for Jenkins EC2
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_EKS_access" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "jenkins_ECR_access" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "jenkins-ec2-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami                    = "ami-0c2b8ca1dad447f8a" # Amazon Linux 2 (latest in us-east-1, update if needed)
  instance_type          = var.jenkins_instance_type
  subnet_id              = local.worker_subnet_ids[0]
  key_name               = aws_key_pair.node_key_pair.key_name
  security_groups        = [aws_security_group.jenkins_sg.id]
}