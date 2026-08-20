terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# ----------------------------
# VARIABLES
# ----------------------------
variable "project_name" {
  type    = string
  default = "aquasense"
}

# ----------------------------
# DATA
# ----------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ----------------------------
# VPC
# ----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ----------------------------
# INTERNET GATEWAY
# ----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ----------------------------
# PUBLIC SUBNETS
# ----------------------------
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-az1"
    Tier = "public"
  }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-az2"
    Tier = "public"
  }
}

# ----------------------------
# PRIVATE SUBNETS
# ----------------------------
resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-az1"
    Tier = "private"
  }
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-private-az2"
    Tier = "private"
  }
}

# ----------------------------
# NAT GATEWAY FOR PRIVATE SUBNET OUTBOUND ACCESS
# ----------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_az1.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}

# ----------------------------
# PUBLIC ROUTE TABLE
# ----------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_az1_assoc" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_az2_assoc" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------------
# PRIVATE ROUTE TABLE WITH NAT
# ----------------------------
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_az1_assoc" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_az2_assoc" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private_rt.id
}

# ----------------------------
# SECURITY GROUP: WEB / ALB
# ----------------------------
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# ----------------------------
# SECURITY GROUP: APP / ECS
# ----------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow app traffic only from ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    description = "Outbound via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# ----------------------------
# SECURITY GROUP: DATABASE
# ----------------------------
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Allow database traffic only from app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL/Aurora from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    description     = "MySQL/Aurora from edge gateway"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.edge_sg.id]
  }

  ingress {
    description     = "MySQL/Aurora from Lambda backend"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

# ----------------------------
# IAM ROLE FOR ECS TASK EXECUTION
# ----------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

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
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ----------------------------
# ECR REPOSITORY
# ----------------------------
resource "aws_ecr_repository" "cwp_repo" {
  name                 = "${var.project_name}-cwp"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "${var.project_name}-cwp-ecr"
    Project = "AquaSense"
    Service = "CustomerWebPortal"
  }
}

# ----------------------------
# CLOUDWATCH LOG GROUP
# ----------------------------
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-cwp"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# ----------------------------
# APPLICATION LOAD BALANCER
# ----------------------------
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]

  subnets = [
    aws_subnet.public_az1.id,
    aws_subnet.public_az2.id
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "cwp_tg" {
  name        = "${var.project_name}-cwp-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-cwp-tg"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cwp_tg.arn
  }
}

# ----------------------------
# ECS CLUSTER
# ----------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-ecs-cluster"

  tags = {
    Name = "${var.project_name}-ecs-cluster"
  }
}

# ----------------------------
# ECS TASK DEFINITION
# ----------------------------
resource "aws_ecs_task_definition" "cwp_task" {
  family                   = "${var.project_name}-cwp-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-cwp"
      image     = "${aws_ecr_repository.cwp_repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "ap-south-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-cwp-task"
  }
}

# ----------------------------
# ECS FARGATE SERVICE IN PRIVATE SUBNETS
# ----------------------------
resource "aws_ecs_service" "cwp_service" {
  name            = "${var.project_name}-cwp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.cwp_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_az1.id,
      aws_subnet.private_az2.id
    ]

    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cwp_tg.arn
    container_name   = "${var.project_name}-cwp"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.http_listener,
    aws_nat_gateway.nat
  ]

  tags = {
    Name = "${var.project_name}-cwp-service"
  }
}

# ----------------------------
# EDGE GATEWAY SECURITY GROUP
# ----------------------------
resource "aws_security_group" "edge_sg" {
  name        = "${var.project_name}-edge-sg"
  description = "Allow SSH access to edge gateway"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH access for edge administration - POC only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    # POC only. For production, restrict to your public IP.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-edge-sg"
  }
}

# ----------------------------
# EC2 EDGE GATEWAY
# ----------------------------
resource "aws_instance" "edge_gateway" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_az1.id
  vpc_security_group_ids      = [aws_security_group.edge_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-pip unzip curl
              pip3 install requests
              echo "AquaSense Edge Gateway Ready" > /home/ubuntu/edge-status.txt
              EOF

  tags = {
    Name = "ASU-Edge-Gateway-01"
    Role = "IoT-Edge-Gateway"
  }
}

# ----------------------------
# OUTPUTS
# ----------------------------
output "ecr_repository_url" {
  value = aws_ecr_repository.cwp_repo.repository_url
}

output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

output "edge_gateway_public_ip" {
  value = aws_instance.edge_gateway.public_ip
}

# ----------------------------
# DYNAMODB TABLE FOR LIVE TELEMETRY
# ----------------------------
resource "aws_dynamodb_table" "live_telemetry" {
  name         = "${var.project_name}-live-telemetry"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "meter_id"
  range_key = "timestamp"

  attribute {
    name = "meter_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name    = "${var.project_name}-live-telemetry"
    Project = "AquaSense"
    Purpose = "HotPathTelemetry"
  }
}

# ----------------------------
# SQS QUEUE FOR CRITICAL ALERTS
# ----------------------------
resource "aws_sqs_queue" "critical_alert_queue" {
  name                       = "${var.project_name}-critical-alert-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  tags = {
    Name    = "${var.project_name}-critical-alert-queue"
    Project = "AquaSense"
    Purpose = "CriticalAlertBuffer"
  }
}

# ----------------------------
# SNS TOPIC FOR INCIDENT NOTIFICATIONS
# ----------------------------
resource "aws_sns_topic" "incident_alerts" {
  name = "${var.project_name}-incident-alerts"

  tags = {
    Name    = "${var.project_name}-incident-alerts"
    Project = "AquaSense"
    Purpose = "IncidentNotification"
  }
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.live_telemetry.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.critical_alert_queue.url
}

output "sns_topic_arn" {
  value = aws_sns_topic.incident_alerts.arn
}

resource "aws_iam_role_policy" "ecs_app_event_pipeline_policy" {
  name = "${var.project_name}-ecs-event-pipeline-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.live_telemetry.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.critical_alert_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.incident_alerts.arn
      }
    ]
  })
}
# =========================================================
# IOT CORE INTEGRATION (ADD BELOW YOUR EXISTING CODE)
# =========================================================

# ----------------------------
# IoT Thing (Edge Device)
# ----------------------------
resource "aws_iot_thing" "edge_gateway" {
  name = "ASU-Edge-Gateway-01"
}

# ----------------------------
# IoT Policy (Allow device to connect & publish)
# ----------------------------
resource "aws_iot_policy" "edge_policy" {
  name = "aquasense-edge-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect",
          "iot:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------------
# IoT Certificate (Device Identity)
# ----------------------------
resource "aws_iot_certificate" "edge_cert" {
  active = true
}

# ----------------------------
# Attach Policy → Certificate
# ----------------------------
resource "aws_iot_policy_attachment" "edge_policy_attach" {
  policy = aws_iot_policy.edge_policy.name
  target = aws_iot_certificate.edge_cert.arn
}

# ----------------------------
# Attach Certificate → Thing
# ----------------------------
resource "aws_iot_thing_principal_attachment" "thing_attach" {
  thing     = aws_iot_thing.edge_gateway.name
  principal = aws_iot_certificate.edge_cert.arn
}

# ----------------------------
# IAM Role for IoT Rule Engine
# ----------------------------
resource "aws_iam_role" "iot_rule_role" {
  name = "aquasense-iot-rule-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ----------------------------
# Allow IoT Rule → DynamoDB
# ----------------------------
resource "aws_iam_role_policy" "iot_dynamodb_policy" {
  name = "aquasense-iot-dynamodb-policy"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.live_telemetry.arn
      }
    ]
  })
}

# ----------------------------
# IoT Rule → DynamoDB
# ----------------------------
resource "aws_iot_topic_rule" "telemetry_rule" {
  name        = "aquasense_telemetry_rule"
  enabled     = true
  sql         = "SELECT * FROM 'aquasense/telemetry'"
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = aws_iam_role.iot_rule_role.arn

    put_item {
      table_name = aws_dynamodb_table.live_telemetry.name
    }
  }
}

# ----------------------------
# OUTPUTS (IMPORTANT)
# ----------------------------
output "iot_certificate_pem" {
  value     = aws_iot_certificate.edge_cert.certificate_pem
  sensitive = true
}

output "iot_private_key" {
  value     = aws_iot_certificate.edge_cert.private_key
  sensitive = true
}

# ----------------------------
# ALLOW IOT RULE → SQS + SNS
# ----------------------------
resource "aws_iam_role_policy" "iot_alert_policy" {
  name = "aquasense-iot-alert-policy"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.critical_alert_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.incident_alerts.arn
      }
    ]
  })
}

# ----------------------------
# IOT RULE → SQS + SNS FOR ALERTS ONLY
# ----------------------------
resource "aws_iot_topic_rule" "alert_rule" {
  name        = "aquasense_alert_rule"
  enabled     = true
  sql         = "SELECT * FROM 'aquasense/telemetry' WHERE status = 'alert'"
  sql_version = "2016-03-23"

  sqs {
    queue_url  = aws_sqs_queue.critical_alert_queue.url
    role_arn   = aws_iam_role.iot_rule_role.arn
    use_base64 = false
  }

  sns {
    target_arn     = aws_sns_topic.incident_alerts.arn
    role_arn       = aws_iam_role.iot_rule_role.arn
    message_format = "RAW"
  }
}

# ----------------------------
# AURORA SUBNET GROUP
# ----------------------------
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name = "${var.project_name}-aurora-subnet-group"

  subnet_ids = [
    aws_subnet.private_az1.id,
    aws_subnet.private_az2.id
  ]

  tags = {
    Name = "${var.project_name}-aurora-subnet-group"
  }
}

# ----------------------------
# AURORA SERVERLESS V2 CLUSTER
# ----------------------------
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier     = "${var.project_name}-aurora-cluster"
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  database_name          = "aquasense"
  master_username        = "adminuser"
  master_password        = "AquaSense12345!"
  db_subnet_group_name   = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  deletion_protection    = false
  storage_encrypted      = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }

  tags = {
    Name    = "${var.project_name}-aurora-cluster"
    Purpose = "CustomerBillingRelationalData"
  }
}

# ----------------------------
# AURORA SERVERLESS V2 INSTANCE
# ----------------------------
resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "${var.project_name}-aurora-instance-1"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version
}

# ----------------------------
# AURORA OUTPUTS
# ----------------------------
output "aurora_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

output "aurora_database_name" {
  value = aws_rds_cluster.aurora_cluster.database_name
}

# ----------------------------
# SECRETS MANAGER - AURORA CREDENTIALS
# ----------------------------
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name = "${var.project_name}/aurora/credentials-v1"

  tags = {
    Name    = "${var.project_name}-aurora-credentials"
    Purpose = "AuroraDatabaseAccess"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_credentials_value" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id

  secret_string = jsonencode({
    host     = aws_rds_cluster.aurora_cluster.endpoint
    database = aws_rds_cluster.aurora_cluster.database_name
    username = "adminuser"
    password = "AquaSense12345!"
    port     = 3306
  })
}

output "aurora_secret_name" {
  value = aws_secretsmanager_secret.aurora_credentials.name
}

# ----------------------------
# LAMBDA SECURITY GROUP
# ----------------------------
resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-lambda-sg"
  description = "Allow Lambda backend to access Aurora"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound to Aurora and AWS services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}


# ----------------------------
# LAMBDA IAM ROLE
# ----------------------------
resource "aws_iam_role" "lambda_crud_role" {
  name = "${var.project_name}-lambda-crud-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ----------------------------
# LAMBDA BASIC EXECUTION POLICY
# ----------------------------
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_crud_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ----------------------------
# LAMBDA VPC ACCESS POLICY
# ----------------------------
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_crud_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ----------------------------
# LAMBDA PERMISSION TO READ AURORA SECRET
# ----------------------------
resource "aws_iam_role_policy" "lambda_secret_access" {
  name = "${var.project_name}-lambda-secret-access"
  role = aws_iam_role.lambda_crud_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.aurora_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.live_telemetry.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.alert_archive_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.user_alerts.arn
      }
    ]
  })
}
# ----------------------------
# CUSTOMER SERVICE LAMBDA
# ----------------------------
resource "aws_lambda_function" "customer_service" {
  function_name = "${var.project_name}-customer-service"
  role          = aws_iam_role.lambda_crud_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  filename      = "customer_lambda.zip"
  source_code_hash = filebase64sha256("customer_lambda.zip")

  timeout     = 30
  memory_size = 256

  vpc_config {
    subnet_ids         = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      SECRET_NAME   = aws_secretsmanager_secret.aurora_credentials.name
      SNS_TOPIC_ARN = aws_sns_topic.user_alerts.arn
    }
  }
}

# ----------------------------
# API GATEWAY HTTP API
# ----------------------------
resource "aws_apigatewayv2_api" "aquasense_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }

  tags = {
    Name    = "${var.project_name}-api"
    Project = "AquaSense"
  }
}

# ----------------------------
# API GATEWAY → CUSTOMER LAMBDA INTEGRATION
# ----------------------------
resource "aws_apigatewayv2_integration" "customer_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.aquasense_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.customer_service.invoke_arn
  payload_format_version = "2.0"
}

# ----------------------------
# GET /customers ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "get_customers" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "GET /customers"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# POST /customers ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "post_customers" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "POST /customers"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# POST /login ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "post_login" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# POST /register ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "post_register" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "POST /register"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# DEFAULT STAGE WITH AUTO DEPLOY
# ----------------------------
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.aquasense_api.id
  name        = "$default"
  auto_deploy = true
}

# ----------------------------
# ALLOW API GATEWAY TO INVOKE CUSTOMER LAMBDA
# ----------------------------
resource "aws_lambda_permission" "allow_api_gateway_customer_lambda" {
  statement_id  = "AllowAPIGatewayInvokeCustomerLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.customer_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.aquasense_api.execution_arn}/*/*"
}

# ----------------------------
# API GATEWAY OUTPUT
# ----------------------------
output "api_gateway_url" {
  value = aws_apigatewayv2_api.aquasense_api.api_endpoint
}

# ----------------------------
# GET /telemetry ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "get_telemetry" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "GET /telemetry"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# GET /alerts ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "get_alerts" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "GET /alerts"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# GET /billing ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "get_billing" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "GET /billing"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# POST /billing/pay ROUTE
# ----------------------------
resource "aws_apigatewayv2_route" "post_billing_pay" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "POST /billing/pay"
  target    = "integrations/${aws_apigatewayv2_integration.customer_lambda_integration.id}"
}

# ----------------------------
# USER SNS TOPIC AND SUBSCRIPTION
# ----------------------------
resource "aws_sns_topic" "user_alerts" {
  name = "user_alerts"
}

resource "aws_sns_topic_subscription" "user_alerts_email" {
  topic_arn = aws_sns_topic.user_alerts.arn
  protocol  = "email"
  endpoint  = "lalanweerasooriya@gmail.com"
}

# ----------------------------
# IAM ROLE FOR IOT TO PUBLISH TO USER SNS
# ----------------------------
resource "aws_iam_role" "iot_user_alert_role" {
  name = "aquasense-iot-user-alert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_user_alert_policy" {
  name = "aquasense-iot-user-alert-policy"
  role = aws_iam_role.iot_user_alert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.user_alerts.arn
      }
    ]
  })
}

# ----------------------------
# IOT ALERT RULE FOR USER
# ----------------------------
resource "aws_iot_topic_rule" "user_alert_rule" {
  # Added '_user' to avoid conflict with existing 'aquasense_alert_rule'
  name        = "aquasense_user_alert_rule"
  enabled     = true
  sql         = "SELECT * FROM 'aquasense/telemetry' WHERE status = 'alert'"
  sql_version = "2016-03-23"

  sns {
    target_arn     = aws_sns_topic.user_alerts.arn
    role_arn       = aws_iam_role.iot_user_alert_role.arn
    message_format = "JSON"
  }
}

# ----------------------------
# NEW SNS ALERTING SYSTEM
# ----------------------------
resource "aws_sns_topic" "aquasense_alerts" {
  name = "aquasense_alerts"
}

resource "aws_sns_topic_subscription" "aquasense_alerts_email" {
  topic_arn = aws_sns_topic.aquasense_alerts.arn
  protocol  = "email"
  endpoint  = "YOUR_EMAIL_HERE@example.com"
}

resource "aws_sqs_queue" "alert_archive_queue" {
  name = "alert_archive_queue"
}

resource "aws_iam_role" "iot_notification_bridge" {
  name = "iot_notification_bridge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

}

resource "aws_iam_role_policy" "iot_sns_policy" {
  name = "iot_sns_policy"
  role = aws_iam_role.iot_notification_bridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.user_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.alert_archive_queue.arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "high_usage_alert" {
  name        = "high_usage_alert"
  enabled     = true
  sql         = "SELECT * FROM 'aquasense/telemetry' WHERE status = 'alert'"
  sql_version = "2016-03-23"

  sns {
    target_arn     = aws_sns_topic.user_alerts.arn
    role_arn       = aws_iam_role.iot_notification_bridge.arn
    message_format = "JSON"
  }

  sqs {
    queue_url  = aws_sqs_queue.alert_archive_queue.url
    role_arn   = aws_iam_role.iot_notification_bridge.arn
    use_base64 = false
  }
}

# ----------------------------
# SECURITY (WAF)
# ----------------------------
resource "aws_wafv2_web_acl" "alb_waf" {
  name        = "${var.project_name}-alb-waf"
  description = "WAF to protect ALB against SQLi"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "SQLiProtection"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiProtection"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-alb-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb_waf_assoc" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}

# ----------------------------
# GOVERNANCE (CloudTrail & S3)
# ----------------------------
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "${var.project_name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_bucket.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main_trail" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  s3_key_prefix                 = "prefix"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}

# ----------------------------
# MONITORING (CloudWatch Alarms)
# ----------------------------
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.cwp_service.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX errors"

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
  }
}

# ----------------------------
# GOVERNANCE (AWS Config)
# ----------------------------
resource "aws_iam_role" "config_role" {
  name = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3_policy" {
  name = "config-s3-policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:PutObject"]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Action = ["s3:GetBucketAcl"]
        Effect = "Allow"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main_recorder" {
  name     = "${var.project_name}-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main_delivery_channel" {
  name           = "${var.project_name}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.cloudtrail_bucket.id

  depends_on = [aws_config_configuration_recorder.main_recorder]
}

resource "aws_config_configuration_recorder_status" "main_recorder_status" {
  name       = aws_config_configuration_recorder.main_recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main_delivery_channel]
}

# ----------------------------
# HYBRID CONNECTIVITY (VPN)
# ----------------------------
resource "aws_customer_gateway" "main_cgw" {
  bgp_asn    = 65000
  ip_address = "1.2.3.4"
  type       = "ipsec.1"

  tags = {
    Name = "${var.project_name}-cgw"
  }
}

resource "aws_vpn_gateway" "main_vgw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-vgw"
  }
}

resource "aws_vpn_connection" "main_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.main_vgw.id
  customer_gateway_id = aws_customer_gateway.main_cgw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "${var.project_name}-site-to-site-vpn"
  }
}

# ----------------------------
# ADMIN STATS SERVICE LAMBDA
# ----------------------------
resource "aws_lambda_function" "admin_stats_service" {
  filename         = "admin_stats_lambda.zip"
  function_name    = "${var.project_name}-admin-stats"
  role             = aws_iam_role.lambda_crud_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("admin_stats_lambda.zip")
  runtime          = "python3.9"
  timeout          = 30

  vpc_config {
    subnet_ids         = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      SECRET_NAME    = aws_secretsmanager_secret.aurora_credentials.name
      DYNAMODB_TABLE = aws_dynamodb_table.live_telemetry.name
    }
  }

  tags = {
    Name    = "${var.project_name}-admin-stats"
    Purpose = "AdminStatisticsAPI"
  }
}

# API Gateway Integration for Admin Stats
resource "aws_apigatewayv2_integration" "admin_stats_integration" {
  api_id           = aws_apigatewayv2_api.aquasense_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.admin_stats_service.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Route for Admin Stats
resource "aws_apigatewayv2_route" "get_admin_stats" {
  api_id    = aws_apigatewayv2_api.aquasense_api.id
  route_key = "GET /admin/stats"
  target    = "integrations/${aws_apigatewayv2_integration.admin_stats_integration.id}"
}

# Permission to invoke Lambda from API Gateway
resource "aws_lambda_permission" "allow_api_gateway_admin_stats" {
  statement_id  = "AllowExecutionFromAPIGatewayAdminStats"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_stats_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.aquasense_api.execution_arn}/*/*"
}




