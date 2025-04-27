# EKS Outputs
output "cluster_name" {
  value = aws_eks_cluster.demo.name
}

output "node_group_stack_status" {
  value = aws_cloudformation_stack.node_group_stack.outputs
}

output "private_key_path" {
  value = var.private_key_path
}

# Jenkins EC2 Outputs
output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_public_dns" {
  value = aws_instance.jenkins.public_dns
}
