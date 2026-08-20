terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Secrets Manager Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-credentials-${var.environment}"
  description             = "Database master credentials for SmartRetailX Aurora cluster"
  recovery_window_in_days = 0 # Force delete on destroy for local/dev flow

  tags = {
    Name        = "${var.project_name}-db-credentials"
    Environment = var.environment
  }
}

# AWS Secrets Manager Secret Value
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_rds_cluster.aurora_cluster.endpoint
    port     = 3306
    username = var.db_master_username
    password = var.db_master_password
    database = var.db_name
  })
}
