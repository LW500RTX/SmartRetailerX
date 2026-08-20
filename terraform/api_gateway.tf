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