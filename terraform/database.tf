# Aurora DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.project_name}-db-subnet-group-${var.environment}"
  description = "DB subnet group for SmartRetailX Aurora private subnets"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier     = "${var.project_name}-aurora-cluster-${var.environment}"
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  database_name          = var.db_name
  master_username        = var.db_master_username
  master_password        = var.db_master_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  deletion_protection    = false
  storage_encrypted      = true

  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_capacity
    max_capacity = var.db_max_capacity
  }

  tags = {
    Name        = "${var.project_name}-aurora-cluster"
    Environment = var.environment
  }
}

# Aurora Serverless v2 Instances (Multi-AZ configuration: 2 instances in different subnets/AZs)
resource "aws_rds_cluster_instance" "aurora_instance" {
  count               = 2
  identifier          = "${var.project_name}-aurora-instance-${count.index + 1}-${var.environment}"
  cluster_identifier  = aws_rds_cluster.aurora_cluster.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.aurora_cluster.engine
  publicly_accessible = false

  tags = {
    Name        = "${var.project_name}-aurora-instance-${count.index + 1}"
    Environment = var.environment
  }
}

# DynamoDB Table for Product Catalogue
resource "aws_dynamodb_table" "products" {
  provider     = aws.primary
  name         = "${var.project_name}-products-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "price"
    type = "N"
  }

  global_secondary_index {
    name               = "CategoryIndex"
    hash_key           = "category"
    range_key          = "price"
    projection_type    = "ALL"
  }

  replica {
    region_name = var.secondary_region
  }

  tags = {
    Name        = "${var.project_name}-products-table"
    Environment = var.environment
  }
}
