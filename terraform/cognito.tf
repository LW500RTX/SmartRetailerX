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
