# SmartRetailX Cloud Architecture Design Documentation

This document describes the cloud-native, microservices-based distributed web application architecture designed and implemented for **SmartRetailX**.

---

## 1. System Architecture Overview

SmartRetailX utilizes a high-availability, secure, and resilient multi-tier microservices architecture deployed on Amazon Web Services (AWS) using **Amazon Elastic Kubernetes Service (EKS)** for container orchestration, and serverless/managed databases for high performance.

```mermaid
graph TD
    Client[Web & Mobile Clients]
    Route53[Amazon Route 53: DNS]
    CF[Amazon CloudFront: CDN]
    Cognito[Amazon Cognito: Auth / JWT]
    APG[Amazon API Gateway: HTTP APIs]
    ALB[Application Load Balancer: ALB]
    VPC[AWS VPC: Private Subnets]
    
    subgraph EKS Compute Tier (Kubernetes)
        US[User Service Pods: Port 5000]
        PS[Product Service Pods: Port 3000]
        OS[Order Service Pods: Port 8000]
        YS[Payment Service Pods: Port 8080]
        IS[Inventory SQS Worker Pods]
        NS[Notification SQS Worker Pods]
    end

    subgraph Data & Persistence Layer
        RDS[(Amazon Aurora MySQL Cluster)]
        DDB[(Amazon DynamoDB Global Table)]
        S3[(Amazon S3: Image Storage)]
        SM[(AWS Secrets Manager)]
    end

    subgraph Event & Messaging Layer
        EB[Amazon EventBridge Event Bus]
        SQS_Inv[SQS Inventory Queue]
        SQS_Not[SQS Notification Queue]
        SNS[Amazon SNS Notification Topic]
    end

    %% Routing Flows
    Client -->|1. Resolve api.smartretailx.internal| Route53
    Client -->|2. Authenticate| Cognito
    Client -->|3. Route HTTPS requests| CF
    CF -->|4. Forward to Origin| APG
    APG -->|5. Forward via VPC Link| ALB
    ALB -->|Route /users| US
    ALB -->|Route /products| PS
    ALB -->|Route /orders| OS
    ALB -->|Route /payments| YS

    %% Database & Config Integration
    US & OS -->|SQL Queries| RDS
    PS -->|NoSQL Catalog Read/Write| DDB
    PS -->|Upload Images| S3
    US & OS -->|Mount DB Password| SM

    %% Event Messaging Flows
    OS -.->|Publish OrderPlaced Event| EB
    EB -.->|Route to SQS| SQS_Inv
    EB -.->|Route to SQS| SQS_Not
    SQS_Inv -.->|Poll Dedact Stock| IS
    SQS_Not -.->|Poll Send Emails| NS
    NS -.->|Trigger Alert| SNS
```

---

## 2. AWS Service Justifications

* **Amazon EKS (Elastic Kubernetes Service)**: Replaces ECS Fargate as the primary compute layer, offering industry-standard container orchestration, native Horizontal Pod Autoscaling (HPA), Service Discovery, and vendor-neutral deployments.
* **Amazon API Gateway**: Acts as the single entrance point (ingress proxy) mapping endpoints, enforcing CORS headers, and securing downstream traffic through Cognito JWT authorizers.
* **Amazon Cognito**: Handles user registration, credentials validation, password complexity, and JWT token issue securely at the edge.
* **Amazon Aurora Serverless v2 (MySQL)**: Provides SQL persistence for orders and customer tables, featuring automated scaling and multi-AZ failovers.
* **Amazon DynamoDB**: Stores the product catalog. DynamoDB's NoSQL model handles arbitrary catalog schemas, and global tables replicate items to standby regions.
* **Amazon S3**: Delivers encrypted (`AES256`), high-durability object storage for hosting product catalogue images and static resources.
* **Amazon EventBridge & SQS**: Implements asynchronous inter-service communication. Order checkout publishes an event to EventBridge, which routes messages down to SQS queues for parallel worker processing, isolating transaction traffic from backend queues.

---

## 3. Resilience and High-Availability Strategy

1. **Multi-AZ Subnets**: All compute, routing, and database subnets span multiple AWS Availability Zones.
2. **Auto-Scaling**: HPAs scale pods based on CPU thresholds, and node groups scale EC2 worker instances.
3. **Database Failover**: Aurora Multi-AZ replication fails over immediately to read replicas during failures, maintaining data availability.
