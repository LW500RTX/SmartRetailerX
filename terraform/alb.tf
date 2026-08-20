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
