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
