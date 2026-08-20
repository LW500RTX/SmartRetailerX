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
