# SmartRetailX — Disaster Recovery & Resilience Plan

**Document Version**: 1.0  
**Last Updated**: 2026-07-27  
**Classification**: Internal / Academic Assessment  
**Primary Region**: `ap-south-1` (Mumbai)  
**Secondary Region**: `eu-central-1` (Frankfurt)

---

## 1. Recovery Objectives

| Metric | Target | Mechanism |
| :--- | :--- | :--- |
| **RTO (Recovery Time Objective)** | < 15 minutes | Route 53 health-check-based DNS failover to secondary region |
| **RPO (Recovery Point Objective)** | < 1 minute | Aurora Global Database asynchronous replication + DynamoDB Global Tables stream replication |

---

## 2. Architecture Resilience Summary

### 2.1 Compute Layer (Amazon EKS)
- **Multi-AZ Deployment**: EKS Managed Node Groups run across private subnets distributed across multiple Availability Zones in `ap-south-1`.
- **Auto-Scaling**: Microservice pods scale horizontally using Horizontal Pod Autoscalers (HPAs) targeting 75% CPU utilization, scaling replicas between 2 and 6.
- **Health Checks**: Kubelet endpoints monitor `/health` liveness probes. Unhealthy containers are automatically terminated and replaced.

### 2.2 Data Layer
- **Aurora Serverless v2 (MySQL)**:
  - Multi-AZ writer + reader instance configuration in the primary region.
  - Aurora Global Database replication target in `eu-central-1` provides sub-second RPO for relational order state.
- **DynamoDB Global Tables**:
  - The `smartretailx-products-production` table is configured with `stream_enabled = true` and a `replica` block in `eu-central-1`.
  - Active-active replication ensures the product catalog is available in both regions simultaneously.

### 2.3 Networking
- **ALB**: Internet-facing Application Load Balancer with HTTPS/TLS termination (ACM certificate on port 443).
- **Security Groups**: Layered ingress rules — ALB accepts public traffic, ECS accepts only ALB-originating traffic, DB accepts only ECS-originating traffic.

### 2.4 Secrets & Configuration
- **AWS Secrets Manager**: Database credentials stored encrypted and injected into ECS task definitions at boot time. Secrets replicate automatically when multi-region is enabled.

---

## 3. Failover Runbook

### Scenario: Primary Region (`ap-south-1`) Becomes Unavailable

#### Step 1 — Detect the Outage (Automated)
- Route 53 health checks monitor the primary ALB endpoint.
- If the health check fails 3 consecutive times (configurable), Route 53 automatically redirects DNS queries to the secondary region's ALB.

#### Step 2 — Promote Secondary Database (Manual / ~5 min)
1. **Aurora Global Database**: Promote the `eu-central-1` Aurora secondary cluster to a standalone writer:
   ```bash
   aws rds failover-global-cluster \
     --global-cluster-identifier smartretailx-global-cluster \
     --target-db-cluster-identifier arn:aws:rds:eu-central-1:ACCOUNT:cluster/smartretailx-secondary \
     --region eu-central-1
   ```
2. **DynamoDB Global Tables**: No action required. The Frankfurt replica is already an active read/write endpoint.

#### Step 3 — Verify Secondary EKS Services (~5 min)
1. Confirm pods are running and healthy in the secondary EKS cluster:
   ```bash
   kubectl get pods -n default --context arn:aws:eks:eu-central-1:ACCOUNT:cluster/smartretailx-eks-production
   ```
2. Verify that ClusterIP services and Horizontal Pod Autoscalers (HPAs) are active:
   ```bash
   kubectl get svc,hpa -n default --context arn:aws:eks:eu-central-1:ACCOUNT:cluster/smartretailx-eks-production
   ```

#### Step 4 — Validate Application Functionality (~3 min)
1. Smoke-test the product catalog:
   ```bash
   curl https://api-dr.smartretailx.com/api/v1/products
   ```
2. Smoke-test order placement (with valid JWT):
   ```bash
   curl -X POST https://api-dr.smartretailx.com/api/v1/orders \
     -H "Authorization: Bearer <cognito-jwt>" \
     -H "Content-Type: application/json" \
     -d '{"customer_id":"test","product_id":"prod-101","quantity":1,"total_amount":4.99}'
   ```

#### Step 5 — Communicate Status
- Update the internal status page.
- Notify stakeholders of the failover event, estimated duration, and any data implications.

---

## 4. Failback Procedure

Once the primary region (`ap-south-1`) recovers:

1. **Re-establish Aurora Global Database replication** from the promoted Frankfurt cluster back to Mumbai.
2. **Verify DynamoDB Global Table sync** — confirm item counts and last-write timestamps match.
3. **Switch Route 53 DNS** back to the primary region ALB endpoint.
4. **Monitor** for 30 minutes to confirm stable traffic flow and zero error rates.

---

## 5. Testing Schedule

| Test Type | Frequency | Description |
| :--- | :--- | :--- |
| **Health Check Validation** | Weekly | Verify ALB health checks are detecting unhealthy targets correctly |
| **Tabletop Failover Exercise** | Monthly | Walk through the runbook with the engineering team without executing |
| **Live Failover Drill** | Quarterly | Execute a controlled failover to the secondary region and validate RTO/RPO targets |
| **Chaos Engineering** | Quarterly | Terminate random ECS tasks during load testing to validate auto-recovery |
