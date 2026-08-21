provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}
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
# Availability Zones Data Source
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Definition
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Public Subnets (across 2 AZs)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier        = "public"
    Environment = var.environment
  }
}

# Private Subnets (across 2 AZs)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Tier        = "private"
    Environment = var.environment
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

# NAT Gateway (placed in public subnet 1)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name        = "${var.project_name}-nat-gateway"
    Environment = var.environment
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Route Table for Private Subnets (via NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# Public Subnet Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
# ALB Security Group (Internet facing)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Access control for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP access from public internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS access from public internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

# ECS / EKS Node Security Group (Backend microservices tier)
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Access control for compute worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow port 3000 from ALB only (Product service)"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow port 5000 from ALB only (User service)"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow port 8000 from ALB only (Order service)"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow port 8080 from ALB only (Payment service)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-sg"
    Environment = var.environment
  }
}

# Database Security Group (Private DB subnet tier)
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Access control for database instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow MySQL traffic from ECS tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    description     = "Allow PostgreSQL traffic from ECS tier only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Allow all outbound traffic (restricted internally)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-sg"
    Environment = var.environment
  }
}
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
# -------------------------------------------------------------
# Amazon RDS Proxy Configuration for Database Connection Pooling
# -------------------------------------------------------------

resource "aws_iam_role" "rds_proxy" {
  name = "${var.project_name}-rds-proxy-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-rds-proxy-role"
    Environment = var.environment
  }
}

resource "aws_db_proxy" "main" {
  name                   = "smartretailx-db-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.db.id]
  vpc_subnet_ids         = aws_subnet.private[*].id

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
    iam_auth    = "DISABLED"
  }

  tags = {
    Name        = "${var.project_name}-db-proxy"
    Environment = var.environment
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "main" {
  db_proxy_name         = aws_db_proxy.main.name
  target_group_name     = aws_db_proxy_default_target_group.main.name
  db_cluster_identifier = aws_rds_cluster.aurora_cluster.id
}
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "smartretailx-cluster-${var.environment}"

  tags = {
    Name        = "${var.project_name}-ecs-cluster"
    Environment = var.environment
  }
}
# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-eks-cluster-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster Definition
resource "
" "main" {
  name     = "${var.project_name}-eks-production"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name        = "${var.project_name}-eks-cluster"
    Environment = var.environment
  }
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-eks-node-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_xray_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# EKS Managed Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 6
    min_size     = 2
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy,
  ]

  tags = {
    Name        = "${var.project_name}-eks-nodegroup"
    Environment = var.environment
  }
}

# --- EKS OIDC Provider for Service Accounts (IRSA) ---

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# --- IAM Role for AWS Load Balancer Controller ---

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-alb-controller-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.project_name}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "IAM Policy for AWS Load Balancer Controller to manage ALBs and Target Groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeMembers",
          "ec2:DescribeRouteTables",
          "ec2:DescribeCoipPools",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACLForResource",
          "waf-regional:GetWebACL",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DeleteProtection",
          "shield:CreateProtection",
          "shield:DescribeSubscription",
          "shield:ListProtections"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DeleteSecurityGroup",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
# ECS Task Execution Role (Allows ECS agent to pull ECR images & write logs)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-ecs-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow Execution Role to read database secret values
resource "aws_iam_role_policy" "ecs_execution_secret_policy" {
  name = "${var.project_name}-ecs-execution-secret-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        aws_secretsmanager_secret.db_credentials.arn
      ]
    }]
  })
}

# ECS Task Role (Granted to running containers to access AWS services)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_xray" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}


# Resource access policies for containers
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDBAccess"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = aws_dynamodb_table.products.arn
      },
      {
        Sid      = "EventBridgeAccess"
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = aws_cloudwatch_event_bus.smartretailx_bus.arn
      },
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:*"]
        Resource = [
          aws_sqs_queue.inventory_processing_queue.arn,
          aws_sqs_queue.notification_processing_queue.arn
        ]
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

# --- TASK DEFINITIONS ---

# Product catalogue service task definition
resource "aws_ecs_task_definition" "product" {
  family                   = "${var.project_name}-product"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1 GB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "product"
      image     = "${aws_ecr_repository.services["product"].repository_url}:latest"
      essential = true

      portMappings = [{
        containerPort = 3000
        hostPort      = 3000
        protocol      = "tcp"
      }]

      environment = [
        { name = "PORT", value = "3000" },
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.products.name },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.product.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = true
      cpu       = 32
      memoryReservation = 256
      portMappings = [{
        containerPort = 2000
        hostPort      = 2000
        protocol      = "udp"
      }]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-product"
    Environment = var.environment
  }
}

# Order service task definition (requires database password injection)
resource "aws_ecs_task_definition" "order" {
  family                   = "${var.project_name}-order"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1 GB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "order"
      image     = "${aws_ecr_repository.services["order"].repository_url}:latest"
      essential = true

      portMappings = [{
        containerPort = 8000
        hostPort      = 8000
        protocol      = "tcp"
      }]

      environment = [
        { name = "PORT", value = "8000" },
        { name = "DB_HOST", value = aws_rds_cluster.aurora_cluster.endpoint },
        { name = "DB_USER", value = var.db_master_username },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_PORT", value = "3306" },
        { name = "EVENT_BUS_NAME", value = aws_cloudwatch_event_bus.smartretailx_bus.name },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      secrets = [{
        name      = "DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.order.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = true
      cpu       = 32
      memoryReservation = 256
      portMappings = [{
        containerPort = 2000
        hostPort      = 2000
        protocol      = "udp"
      }]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-order"
    Environment = var.environment
  }
}

# Inventory background worker task definition
resource "aws_ecs_task_definition" "inventory" {
  family                   = "${var.project_name}-inventory"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1 GB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "inventory"
      image     = "${aws_ecr_repository.services["inventory"].repository_url}:latest"
      essential = true

      environment = [
        { name = "SQS_QUEUE_URL", value = aws_sqs_queue.inventory_processing_queue.id },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.inventory.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = true
      cpu       = 32
      memoryReservation = 256
      portMappings = [{
        containerPort = 2000
        hostPort      = 2000
        protocol      = "udp"
      }]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-inventory"
    Environment = var.environment
  }
}

# --- ECS SERVICES ---

# Product Catalogue Service
resource "aws_ecs_service" "product" {
  name            = "${var.project_name}-product-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product.arn
    container_name   = "product"
    container_port   = 3000
  }

  tags = {
    Name        = "${var.project_name}-product-service"
    Environment = var.environment
  }
}

# Order Processing Service
resource "aws_ecs_service" "order" {
  name            = "${var.project_name}-order-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order.arn
    container_name   = "order"
    container_port   = 8000
  }

  tags = {
    Name        = "${var.project_name}-order-service"
    Environment = var.environment
  }
}

# Inventory Background Service (No Load Balancer required)
resource "aws_ecs_service" "inventory" {
  name            = "${var.project_name}-inventory-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.inventory.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name        = "${var.project_name}-inventory-service"
    Environment = var.environment
  }
}

# --- PAYMENT SERVICE ---

# Payment service task definition
resource "aws_ecs_task_definition" "payment" {
  family                   = "${var.project_name}-payment"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "payment"
      image     = "${aws_ecr_repository.services["payment"].repository_url}:latest"
      essential = true

      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]

      environment = [
        { name = "PORT", value = "8080" },
        { name = "EVENT_BUS_NAME", value = aws_cloudwatch_event_bus.smartretailx_bus.name },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.payment.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = true
      cpu       = 32
      memoryReservation = 256
      portMappings = [{
        containerPort = 2000
        hostPort      = 2000
        protocol      = "udp"
      }]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-payment"
    Environment = var.environment
  }
}

# Payment Service (ALB-attached)
resource "aws_ecs_service" "payment" {
  name            = "${var.project_name}-payment-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payment.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.payment.arn
    container_name   = "payment"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener_rule.payment_rule]

  tags = {
    Name        = "${var.project_name}-payment-service"
    Environment = var.environment
  }
}

# --- NOTIFICATION SERVICE ---

# Notification background worker task definition
resource "aws_ecs_task_definition" "notification" {
  family                   = "${var.project_name}-notification"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "notification"
      image     = "${aws_ecr_repository.services["notification"].repository_url}:latest"
      essential = true

      environment = [
        { name = "SQS_NOTIFICATION_QUEUE_URL", value = aws_sqs_queue.notification_processing_queue.id },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.notification.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = true
      cpu       = 32
      memoryReservation = 256
      portMappings = [{
        containerPort = 2000
        hostPort      = 2000
        protocol      = "udp"
      }]
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-notification"
    Environment = var.environment
  }
}

# Notification Background Service (No Load Balancer required)
resource "aws_ecs_service" "notification" {
  name            = "${var.project_name}-notification-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.notification.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name        = "${var.project_name}-notification-service"
    Environment = var.environment
  }
}

# =============================================
# ECS APPLICATION AUTO SCALING
# =============================================

# --- Product Service Auto Scaling ---

resource "aws_appautoscaling_target" "product_scaling_target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.product.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "product_cpu_scaling" {
  name               = "${var.project_name}-product-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.product_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.product_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.product_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "product_memory_scaling" {
  name               = "${var.project_name}-product-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.product_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.product_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.product_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

# --- Order Service Auto Scaling ---

resource "aws_appautoscaling_target" "order_scaling_target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.order.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "order_cpu_scaling" {
  name               = "${var.project_name}-order-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.order_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.order_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.order_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "order_memory_scaling" {
  name               = "${var.project_name}-order-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.order_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.order_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.order_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "smartretailx_alb" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# --- TARGET GROUPS ---

# Target Group: Product Catalogue Service (Port 3000)
resource "aws_lb_target_group" "product" {
  name        = "${var.project_name}-tg-prod-${var.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-tg-product"
    Environment = var.environment
  }
}

# Target Group: Order Processing Service (Port 8000)
resource "aws_lb_target_group" "order" {
  name        = "${var.project_name}-tg-order-${var.environment}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-tg-order"
    Environment = var.environment
  }
}

# Target Group: Payment Service (Port 8080)
resource "aws_lb_target_group" "payment" {
  name        = "${var.project_name}-tg-pay-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-tg-payment"
    Environment = var.environment
  }
}

# --- LISTENERS ---

# ALB HTTP Listener (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.smartretailx_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "SmartRetailX ALB Active"
      status_code  = "200"
    }
  }
}

# --- ROUTING RULES ---

# Routing Rule: Route /api/v1/products* to Product TG
resource "aws_lb_listener_rule" "product_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/products*"]
    }
  }
}

# Routing Rule: Route /api/v1/orders* to Order TG
resource "aws_lb_listener_rule" "order_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/orders*"]
    }
  }
}

# Routing Rule: Route /api/v1/payments* to Payment TG
resource "aws_lb_listener_rule" "payment_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payment.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/payments*"]
    }
  }
}
# HTTP API Gateway
resource "aws_apigatewayv2_api" "smartretailx_api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name        = "${var.project_name}-api-gateway"
    Environment = var.environment
  }
}

# API Gateway default deployment stage with auto-deploy enabled
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.smartretailx_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
  }
}

# JWT Authorizer linked to our Cognito User Pool
resource "aws_apigatewayv2_authorizer" "cognito_authorizer" {
  api_id           = aws_apigatewayv2_api.smartretailx_api.id
  name             = "${var.project_name}-cognito-authorizer-${var.environment}"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.smartretailx_app_client.id]
    issuer   = "https://${aws_cognito_user_pool.smartretailx_users.endpoint}"
  }
}

# VPC Link to allow API Gateway to communicate with resources in the private subnets
resource "aws_apigatewayv2_vpc_link" "alb_link" {
  name               = "${var.project_name}-vpc-link-${var.environment}"
  security_group_ids = [aws_security_group.ecs.id]
  subnet_ids         = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-api-vpc-link"
    Environment = var.environment
  }
}

# HTTP Proxy Integration pointing to the ALB Listener ARN
resource "aws_apigatewayv2_integration" "alb_integration" {
  api_id             = aws_apigatewayv2_api.smartretailx_api.id
  integration_type   = "HTTP_PROXY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.alb_link.id 
  integration_uri    = aws_lb_listener.http.arn
  integration_method = "ANY"
}

# CORS Preflight OPTIONS Route (Unauthenticated so browsers can perform CORS preflights)
resource "aws_apigatewayv2_route" "options_catch_all" {
  api_id             = aws_apigatewayv2_api.smartretailx_api.id
  route_key          = "OPTIONS /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
  authorization_type = "NONE"
}

# Catch-all Route: Route all requests to ALB via VPC Link (Validation handled by microservices)
resource "aws_apigatewayv2_route" "catch_all" {
  api_id             = aws_apigatewayv2_api.smartretailx_api.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
  authorization_type = "NONE"
}
# Route 53 Private Hosted Zone inside the custom VPC
resource "aws_route53_zone" "internal" {
  name = "smartretailx.internal"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-hosted-zone"
    Environment = var.environment
  }
}

# CloudFront Distribution securely routing to API Gateway
resource "aws_cloudfront_distribution" "api_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Edge Distribution for SmartRetailX API Gateway Gateway integration"
  price_class         = "PriceClass_100" # Limit distribution footprint to minimize costs

  # Custom Origin mapping to API Gateway HTTP Endpoint
  origin {
    domain_name = replace(aws_apigatewayv2_api.smartretailx_api.api_endpoint, "https://", "")
    origin_id   = "APIGatewayOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior configured for dynamic API requests (No-Caching bypass)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "APIGatewayOrigin"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Accept", "Content-Type"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # Basic Geo Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer SSL Certificate mapping (utilizing default CloudFront domain certificate)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-api-cloudfront"
    Environment = var.environment
  }
}

# Route 53 Alias Record mapping api.smartretailx.internal to CloudFront
resource "aws_route53_record" "api_alias" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "api.smartretailx.internal"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.api_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
# Cognito User Pool for SmartRetailX Users
resource "aws_cognito_user_pool" "smartretailx_users" {
  name = "${var.project_name}-users-${var.environment}"

  # Password strength policy (min 8 chars, uppercase, number, symbol)
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Custom 'role' attribute for Role-Based Access Control
  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "role"
    required                 = false

    string_attribute_constraints {
      min_length = 1
      max_length = 20
    }
  }

  # Allow user sign up with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_message        = "Your verification code is {####}."
    email_subject        = "Verify your SmartRetailX account"
  }

  tags = {
    Name        = "${var.project_name}-user-pool"
    Environment = var.environment
  }
}

# Cognito User Pool Client configuration
resource "aws_cognito_user_pool_client" "smartretailx_app_client" {
  name         = "${var.project_name}-app-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.smartretailx_users.id

  # Auth flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Prevent sharing client secret on client applications
  generate_secret = false
}
# Custom EventBridge Event Bus for microservices communication
resource "aws_cloudwatch_event_bus" "smartretailx_bus" {
  name = "${var.project_name}-bus-${var.environment}"

  tags = {
    Name        = "${var.project_name}-bus"
    Environment = var.environment
  }
}

# SQS Queue for Inventory Processing microservice
resource "aws_sqs_queue" "inventory_processing_queue" {
  name                      = "${var.project_name}-inventory-processing-queue-${var.environment}"
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10 # Default to long polling

  tags = {
    Name        = "${var.project_name}-inventory-processing-queue"
    Environment = var.environment
  }
}

# EventBridge Rule: Filter for 'OrderPlaced' events originating from order service
resource "aws_cloudwatch_event_rule" "order_placed_rule" {
  name           = "${var.project_name}-order-placed-rule-${var.environment}"
  description    = "Capture OrderPlaced events and route to SQS queue"
  event_bus_name = aws_cloudwatch_event_bus.smartretailx_bus.name

  event_pattern = jsonencode({
    source      = ["smartretailx.order"]
    detail-type = ["OrderPlaced"]
  })

  tags = {
    Name        = "${var.project_name}-order-placed-rule"
    Environment = var.environment
  }
}

# Target: Route matched events to SQS Queue
resource "aws_cloudwatch_event_target" "sqs_target" {
  event_bus_name = aws_cloudwatch_event_bus.smartretailx_bus.name
  rule           = aws_cloudwatch_event_rule.order_placed_rule.name
  target_id      = "SendToSQS"
  arn            = aws_sqs_queue.inventory_processing_queue.arn
}

# SQS Queue Policy: Allow EventBridge to send messages to the SQS queue
resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.inventory_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToQueue"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.inventory_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.order_placed_rule.arn
          }
        }
      }
    ]
  })
}

# --- NOTIFICATION SERVICE EVENT WIRING ---

# SQS Queue for Notification Processing microservice
resource "aws_sqs_queue" "notification_processing_queue" {
  name                      = "${var.project_name}-notification-processing-queue-${var.environment}"
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10

  tags = {
    Name        = "${var.project_name}-notification-processing-queue"
    Environment = var.environment
  }
}

# EventBridge Rule: Capture OrderPlaced AND PaymentProcessed events for notifications
resource "aws_cloudwatch_event_rule" "notification_events_rule" {
  name           = "${var.project_name}-notification-events-rule-${var.environment}"
  description    = "Capture OrderPlaced and PaymentProcessed events and route to notification SQS queue"
  event_bus_name = aws_cloudwatch_event_bus.smartretailx_bus.name

  event_pattern = jsonencode({
    source      = ["smartretailx.order", "smartretailx.payment"]
    detail-type = ["OrderPlaced", "PaymentProcessed"]
  })

  tags = {
    Name        = "${var.project_name}-notification-events-rule"
    Environment = var.environment
  }
}

# Target: Route matched notification events to Notification SQS Queue
resource "aws_cloudwatch_event_target" "notification_sqs_target" {
  event_bus_name = aws_cloudwatch_event_bus.smartretailx_bus.name
  rule           = aws_cloudwatch_event_rule.notification_events_rule.name
  target_id      = "SendToNotificationSQS"
  arn            = aws_sqs_queue.notification_processing_queue.arn
}

# SQS Queue Policy: Allow EventBridge to send messages to the Notification queue
resource "aws_sqs_queue_policy" "notification_sqs_policy" {
  queue_url = aws_sqs_queue.notification_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToNotificationQueue"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.notification_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.notification_events_rule.arn
          }
        }
      }
    ]
  })
}

# --- REAL-TIME PRICING AND PROMOTIONS EVENT RULE ---

# EventBridge Rule: Filter for 'PriceAndPromotionUpdate' events originating from product/admin service
resource "aws_cloudwatch_event_rule" "price_promotion_update_rule" {
  name           = "${var.project_name}-price-promotion-update-rule-${var.environment}"
  description    = "Capture PriceAndPromotionUpdate events for real-time frontend propagation and cache invalidation"
  event_bus_name = aws_cloudwatch_event_bus.smartretailx_bus.name

  event_pattern = jsonencode({
    source      = ["smartretailx.product", "smartretailx.admin"]
    detail-type = ["PriceAndPromotionUpdate", "PriceAndPromotionUpdated"]
  })

  tags = {
    Name        = "${var.project_name}-price-promotion-update-rule"
    Environment = var.environment
  }
}
resource "aws_iam_role" "lambda_exec" {
  name = "smartretailx-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_custom" {
  name        = "smartretailx-lambda-custom-policy"
  description = "Custom policy for SmartRetailX Lambdas to access DynamoDB and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [aws_dynamodb_table.products.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_custom_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_custom.arn
}

resource "aws_cloudwatch_log_group" "admin_stats" {
  name              = "/aws/lambda/smartretailx-admin-stats"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "customer_service" {
  name              = "/aws/lambda/smartretailx-customer-service"
  retention_in_days = 7
}

resource "aws_lambda_function" "admin_stats" {
  filename      = "${path.module}/../backend/lambda/admin-stats/admin_stats_lambda.zip"
  function_name = "smartretailx-admin-stats"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      SECRET_NAME    = aws_secretsmanager_secret.db_credentials.name
      DYNAMODB_TABLE = aws_dynamodb_table.products.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.admin_stats,
    aws_iam_role_policy_attachment.lambda_custom_attach
  ]
}

resource "aws_lambda_function" "customer_service" {
  filename      = "${path.module}/../backend/lambda/customer-service/customer_lambda.zip"
  function_name = "smartretailx-customer-service"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      SECRET_NAME = aws_secretsmanager_secret.db_credentials.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.customer_service,
    aws_iam_role_policy_attachment.lambda_custom_attach
  ]
}
# ---------------------------------------------------------------
# AWS SES (Simple Email Service) Configuration for SmartRetailX
# Notification Service Email Delivery Infrastructure
# ---------------------------------------------------------------

# SES Email Identity — Verified sender address for transactional emails
resource "aws_ses_email_identity" "notification_sender" {
  email = var.ses_sender_email
}

# SES Configuration Set — Tracking, reputation, and delivery metrics
resource "aws_ses_configuration_set" "smartretailx_ses_config" {
  name = "${var.project_name}-ses-config-${var.environment}"

  delivery_options {
    tls_policy = "Require"
  }
}

# IAM Policy: Allow notification-service pods to send emails via SES
resource "aws_iam_policy" "ses_send_email_policy" {
  name        = "${var.project_name}-ses-send-email-policy-${var.environment}"
  description = "Allows SmartRetailX notification service to send transactional emails via Amazon SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESSendEmail"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSESGetIdentity"
        Effect = "Allow"
        Action = [
          "ses:GetIdentityVerificationAttributes",
          "ses:VerifyEmailIdentity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ses-send-email-policy"
    Environment = var.environment
  }
}

# Attach SES policy to the EKS node role so notification-service pods inherit permissions
resource "aws_iam_role_policy_attachment" "ses_policy_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.ses_send_email_policy.arn
}
# CloudWatch Log Group: Product service
resource "aws_cloudwatch_log_group" "product" {
  name              = "/ecs/${var.project_name}-product-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group-product"
    Environment = var.environment
  }
}

# CloudWatch Log Group: Order service
resource "aws_cloudwatch_log_group" "order" {
  name              = "/ecs/${var.project_name}-order-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group-order"
    Environment = var.environment
  }
}

# CloudWatch Log Group: Inventory service
resource "aws_cloudwatch_log_group" "inventory" {
  name              = "/ecs/${var.project_name}-inventory-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group-inventory"
    Environment = var.environment
  }
}

# CloudWatch Performance Dashboard
resource "aws_cloudwatch_dashboard" "performance" {
  dashboard_name = "SmartRetailX-Performance"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.smartretailx_alb.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Total Request Count (Sum)"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.smartretailx_alb.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.smartretailx_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB HTTP 5XX Errors Rate (Sum)"
          view   = "timeSeries"
        }
      }
    ]
  })
}

# CloudWatch Log Group: Payment service
resource "aws_cloudwatch_log_group" "payment" {
  name              = "/ecs/${var.project_name}-payment-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group-payment"
    Environment = var.environment
  }
}

# CloudWatch Log Group: Notification service
resource "aws_cloudwatch_log_group" "notification" {
  name              = "/ecs/${var.project_name}-notification-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group-notification"
    Environment = var.environment
  }
}

# CloudWatch Log Group: User service
resource "aws_cloudwatch_log_group" "user" {
  name              = "/ecs/${var.project_name}-user-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group-user"
    Environment = var.environment
  }
}

# CloudWatch Metric Alarm for elevated ALB HTTP 5XX Errors
resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  alarm_name          = "${var.project_name}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10 # Trigger if more than 10 requests fail with 5XX in 1 minute
  alarm_description   = "Alert when Target 5XX error count exceeds threshold limits."
  alarm_actions       = [aws_sns_topic.notifications.arn]

  dimensions = {
    LoadBalancer = aws_lb.smartretailx_alb.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-alarm-5xx"
    Environment = var.environment
  }
}
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
