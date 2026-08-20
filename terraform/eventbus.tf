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
