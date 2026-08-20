#!/bin/bash
echo "Initializing local AWS resources inside LocalStack..."

# 1. Create DynamoDB table matching our schema
awslocal dynamodb create-table \
    --table-name smartretailx-products-production \
    --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S \
    --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region ap-south-1

# 2. Create SQS Queues for Inventory and Notification Services
awslocal sqs create-queue \
    --queue-name smartretailx-inventory-processing-queue \
    --region ap-south-1

awslocal sqs create-queue \
    --queue-name smartretailx-notification-queue \
    --region ap-south-1

# 3. Create Custom EventBridge Event Bus
awslocal events create-event-bus \
    --name smartretailx-bus \
    --region ap-south-1

# 4. Create EventBridge Rule on the custom bus matching OrderPlaced events
awslocal events put-rule \
    --name smartretailx-order-placed-rule \
    --event-bus-name smartretailx-bus \
    --event-pattern "{\"source\": [\"smartretailx.order\"], \"detail-type\": [\"OrderPlaced\"]}" \
    --region ap-south-1

# 5. Create Targets mapping Rule to SQS Queues
awslocal events put-targets \
    --rule smartretailx-order-placed-rule \
    --event-bus-name smartretailx-bus \
    --targets "[{\"Id\":\"1\",\"Arn\":\"arn:aws:sqs:ap-south-1:000000000000:smartretailx-inventory-processing-queue\"},{\"Id\":\"2\",\"Arn\":\"arn:aws:sqs:ap-south-1:000000000000:smartretailx-notification-queue\"}]" \
    --region ap-south-1

# 6. Verify SES email identity locally in LocalStack
awslocal ses verify-email-identity \
    --email-address lalanweerasooriya@gmail.com \
    --region ap-south-1

echo "Local Event Bus, SQS Queues (Inventory & Notification), SES Identity, and Target mappings initialized successfully!"
