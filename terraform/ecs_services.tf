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

