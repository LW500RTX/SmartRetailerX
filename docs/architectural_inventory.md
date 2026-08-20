# SmartRetailX Deployed AWS Infrastructure Inventory

This document provides a comprehensive resource inventory of the AWS cloud infrastructure configured for the **SmartRetailX** microservices platform. It maps exact resource names, logical configurations, and inter-service relationships to serve as a design blueprint for draw.io or Mermaid architectural diagrams.

---

## 1. Edge & DNS Layer

Handles client access resolution and edge SSL caching:

*   **Amazon Route 53 Private Hosted Zone**:
    *   **Logical ID**: `aws_route53_zone.internal` ([edge.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/edge.tf#L2-L13))
    *   **Domain Name**: `smartretailx.internal`
    *   **Scope**: Bound to VPC `vpc.main.id` to enable internal DNS resolution.
*   **Route 53 DNS Alias Record**:
    *   **Logical ID**: `aws_route53_record.api_alias` ([edge.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/edge.tf#L68-L79))
    *   **Endpoint**: `api.smartretailx.internal`
    *   **Target**: Alias A record pointing to the CloudFront distribution domain name.
*   **Amazon CloudFront Distribution**:
    *   **Logical ID**: `aws_cloudfront_distribution.api_cdn` ([edge.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/edge.tf#L16-L65))
    *   **Origin ID**: `APIGatewayOrigin`
    *   **Viewer Protocol**: Redirects HTTP to HTTPS (`redirect-to-https`).
    *   **Forwarded Headers**: Pass `Authorization`, `Origin`, `Accept`, and `Content-Type` to dynamic API routes.

---

## 2. Ingress & Routing Layer

Bridges public traffic from the edge to the private EKS compute tier:

*   **Amazon API Gateway v2 HTTP API**:
    *   **Logical ID**: `aws_apigatewayv2_api.smartretailx_api` ([api_gateway.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/api_gateway.tf#L2-L8))
    *   **Protocol Type**: `HTTP`
*   **API Gateway VPC Link**:
    *   **Logical ID**: `aws_apigatewayv2_vpc_link.alb_link` ([api_gateway.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/api_gateway.tf#L47-L52))
    *   **Subnets**: Spans two private subnets in the custom VPC.
*   **HTTP Proxy Integration**:
    *   **Logical ID**: `aws_apigatewayv2_integration.alb_integration` ([api_gateway.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/api_gateway.tf#L55-L63))
    *   **Connection Type**: `VPC_LINK`
    *   **Integration URI**: Connected to the Application Load Balancer HTTP listener ARN (`aws_lb_listener.http.arn`).
*   **Application Load Balancer (ALB)**:
    *   **Logical ID**: `aws_lb.smartretailx_alb` ([alb.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/alb.tf#L2-L13))
    *   **Scheme**: `internet-facing`
    *   **Subnets**: Distributed across public subnets (`aws_subnet.public.*.id`).

---

## 3. Compute & Orchestration Layer

Hosts and scales the containerized microservices suite:

*   **Amazon EKS Cluster**:
    *   **Logical ID**: `aws_eks_cluster.main` ([eks.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/eks.tf#L25-L42))
    *   **Resource Name**: `smartretailx-eks-production`
    *   **Subnets**: Spans private subnets (`aws_subnet.private.*.id`).
*   **Managed Node Group**:
    *   **Logical ID**: `aws_eks_node_group.main` ([eks.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/eks.tf#L88-L113))
    *   **Scaling Configuration**: Scaling bounds of 2–6 EC2 worker nodes (`t3.medium`).
*   **Kubernetes Pod Deployments & ClusterIP Services**:
    *   Configured under [/k8s manifests](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/k8s/):
        1.  `user-service` (Port 5000)
        2.  `product-service` (Port 3000)
        3.  `order-service` (Port 8000)
        4.  `payment-service` (Port 8080)
        5.  `inventory-service` (Background event SQS poller)
        6.  `notification-service` (Background event SQS poller, Port 9000)
*   **Horizontal Pod Autoscalers (HPAs)**:
    *   Target: **75% average CPU utilization**.
    *   Boundary Scale: 2–6 dynamic Pod replicas per microservice workload.

---

## 4. Asynchronous Messaging & Event-Driven Layer

Enables loosely coupled, message-driven service communication:

*   **Amazon EventBridge Event Bus**:
    *   **Logical ID**: `aws_cloudwatch_event_bus.smartretailx_bus` ([eventbus.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/eventbus.tf#L2-L4))
    *   **Resource Name**: `smartretailx-bus-production`
*   **Amazon SQS Processing & Dead Letter Queues (DLQs)**:
    *   **Inventory Queue**: `smartretailx-inventory-processing-queue` (Line 12) + DLQ `smartretailx-inventory-processing-dlq` (Line 20).
    *   **Notification Queue**: `smartretailx-notification-queue` (Line 76) + DLQ `smartretailx-notification-processing-dlq` (Line 84).
*   **EventBridge Routing Rules**:
    *   `aws_cloudwatch_event_rule.order_placed_rule` (Line 24) routes `OrderPlaced` events to SQS.
    *   `aws_cloudwatch_event_rule.notification_events_rule` (Line 88) routes notification payloads.

---

## 5. Data & Storage Layer

Provides persistent data layers:

*   **Amazon Aurora Serverless v2 (MySQL)**:
    *   **Logical ID**: `aws_rds_cluster.aurora_cluster` ([database.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/database.tf#L14-L37))
    *   **Cluster Endpoint**: `smartretailx-aurora-cluster-production.cluster-c5s2sm2um2q6.ap-south-1.rds.amazonaws.com`
    *   **Scaling Boundary**: 0.5 to 2.0 ACUs (Aurora Capacity Units).
    *   **Availability**: Multi-AZ layout utilizing 2 instances: `aws_rds_cluster_instance.aurora_instance` with `count = 2`.
*   **Amazon DynamoDB Table**:
    *   **Logical ID**: `aws_dynamodb_table.products` ([database.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/database.tf#L54-L79))
    *   **TableName**: `smartretailx-products-production`
    *   **Primary Keys**: Partition Key `PK` (String), Sort Key `SK` (String).
    *   **Multi-Region DR**: Replicates table state to secondary region `eu-central-1` via a replica block (Line 74).
*   **Amazon S3 Static Bucket**:
    *   **Logical ID**: `aws_s3_bucket.product_images` ([resources.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/resources.tf#L2-L10))
    *   **Bucket Name**: `smartretailx-product-images-production`
    *   **SSE Encryption**: `AES256` enabled.

---

## 6. Security, Identity & Observability Layer

Secures endpoints, controls secrets, and tracks telemetry metrics:

*   **Amazon Cognito User Pool**:
    *   **Logical ID**: `aws_cognito_user_pool.smartretailx_pool` ([cognito.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/cognito.tf#L2-L33))
*   **AWS Secrets Manager Database Secret**:
    *   **Logical ID**: `aws_secretsmanager_secret.db_secret` ([database.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/database.tf#L104-L109))
    *   **Usage**: Maps db credentials into EKS Namespace `database-credentials` secrets.
*   **CloudWatch Log Groups**:
    *   `aws_cloudwatch_log_group.user` ([observability.tf](file:///d:/CB013212/3%20year%20sem%203/Cloud/SmartRetailX/terraform/observability.tf#L101-L109)) retention set to 7 days.
*   **CloudWatch Performance Dashboard**:
    *   `aws_cloudwatch_dashboard.performance` (Line 35) maps HTTP target counts and 5XX error graphs.
*   **CloudWatch Metric Alarm**:
    *   `aws_cloudwatch_metric_alarm.high_5xx_errors` (Line 112) triggers alerts on 5XX errors and routes to the SNS topic.
