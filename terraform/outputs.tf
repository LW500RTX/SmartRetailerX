output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "public_subnets" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs"
}

output "private_subnets" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs"
}

output "db_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "The ARN of the Secrets Manager secret for database credentials"
}

output "db_credentials_secret_name" {
  value       = aws_secretsmanager_secret.db_credentials.name
  description = "The Name of the Secrets Manager secret for database credentials"
}

output "aurora_endpoint" {
  value       = aws_rds_cluster.aurora_cluster.endpoint
  description = "The writer endpoint of the Aurora cluster"
}

output "aurora_reader_endpoint" {
  value       = aws_rds_cluster.aurora_cluster.reader_endpoint
  description = "The read-only endpoint of the Aurora cluster"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.products.name
  description = "The name of the DynamoDB products table"
}

output "eks_cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "The name of the EKS cluster"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "The endpoint of the EKS cluster"
}

output "eks_cluster_certificate_authority_data" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "The certificate authority data of the EKS cluster"
}

output "eks_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.eks.arn
  description = "The ARN of the EKS OIDC provider"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.smartretailx_users.id
  description = "The ID of the Cognito User Pool"
}

output "cognito_user_pool_client_id" {
  value       = aws_cognito_user_pool_client.smartretailx_app_client.id
  description = "The ID of the Cognito User Pool Client"
}

output "api_gateway_endpoint" {
  value       = aws_apigatewayv2_api.smartretailx_api.api_endpoint
  description = "The endpoint URL of the HTTP API Gateway"
}

output "alb_dns_name" {
  value       = aws_lb.smartretailx_alb.dns_name
  description = "The public DNS endpoint of the Application Load Balancer"
}
