variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into"
  default     = "ap-south-1"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "smartretailx"
}

variable "environment" {
  type        = string
  description = "The deployment environment name"
  default     = "production"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "db_name" {
  type        = string
  description = "The initial database name inside the Aurora cluster"
  default     = "smartretailx"
}

variable "db_master_username" {
  type        = string
  description = "The master username for the Aurora database cluster"
  default     = "dbadmin"
}

variable "db_master_password" {
  type        = string
  description = "The master password for the Aurora database cluster. Highly recommended to override via TF_VAR_db_master_password."
  default     = "SmartRetailXSecurePass123!"
  sensitive   = true
}

variable "db_min_capacity" {
  type        = number
  description = "Minimum capacity (ACUs) for Aurora Serverless v2 scaling"
  default     = 0.5
}

variable "db_max_capacity" {
  type        = number
  description = "Maximum capacity (ACUs) for Aurora Serverless v2 scaling"
  default     = 2.0
}

variable "primary_region" {
  type        = string
  description = "The primary AWS region for deployment"
  default     = "ap-south-1"
}

variable "secondary_region" {
  type        = string
  description = "The secondary AWS region for cross-region replication"
  default     = "eu-central-1"
}

variable "ses_sender_email" {
  type        = string
  description = "The verified sender email address for SES transactional email delivery"
  default     = "lalanweerasooriya@gmail.com"
}
