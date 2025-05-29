output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "grafana_secret_command" {
  description = "AWS CLI command to retrieve the Grafana admin password"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.grafana.name} --query 'SecretString' --output text"
}
