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
