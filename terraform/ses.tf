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
