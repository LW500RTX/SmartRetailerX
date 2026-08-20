#!/bin/bash
# SmartRetailX microservices ECR deployment script
set -e

AWS_ACCOUNT_ID="813226680753"
AWS_REGION="ap-south-1"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Authenticating Docker with AWS ECR for region ${AWS_REGION}..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}

# 1. Product Service
echo "--------------------------------------------------"
echo "Building, tagging, and pushing smartretailx-product..."
docker build -t smartretailx-product ./services/product-service
docker tag smartretailx-product:latest ${REGISTRY}/smartretailx-product:latest
docker push ${REGISTRY}/smartretailx-product:latest

# 2. Order Service
echo "--------------------------------------------------"
echo "Building, tagging, and pushing smartretailx-order..."
docker build -t smartretailx-order ./services/order-service
docker tag smartretailx-order:latest ${REGISTRY}/smartretailx-order:latest
docker push ${REGISTRY}/smartretailx-order:latest

# 3. Inventory Service
echo "--------------------------------------------------"
echo "Building, tagging, and pushing smartretailx-inventory..."
docker build -t smartretailx-inventory ./services/inventory-service
docker tag smartretailx-inventory:latest ${REGISTRY}/smartretailx-inventory:latest
docker push ${REGISTRY}/smartretailx-inventory:latest

echo "--------------------------------------------------"
echo "Deployment completed successfully! All images pushed to ECR."
