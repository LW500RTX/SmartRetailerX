# Elastic Container Registry (ECR) Repositories created by resource "aws_ecr_repository" "services" below

# Amazon S3 Bucket for Product Images & Invoices
resource "aws_s3_bucket" "product_images" {
  bucket        = "smartretailx-product-images-production-110982594518"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-product-images"
    Environment = var.environment
  }
}

# S3 Server-Side Encryption Configuration (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "product_images_sse" {
  bucket = aws_s3_bucket.product_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Public Access Block (Ensures bucket is private and secured)
resource "aws_s3_bucket_public_access_block" "product_images_privacy" {
  bucket = aws_s3_bucket.product_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Elastic Container Registry (ECR) Repositories for Microservices
resource "aws_ecr_repository" "services" {
  for_each             = toset(["product", "order", "inventory", "payment", "notification", "user"])
  name                 = "smartretailx-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "smartretailx-${each.key}-ecr"
    Environment = var.environment
  }
}

# Amazon SNS Topic for System & Order Notifications
resource "aws_sns_topic" "notifications" {
  name = "smartretailx-notifications-topic-production"

  tags = {
    Name        = "${var.project_name}-notifications-topic"
    Environment = var.environment
  }
}
