# SmartRetailX Fault Diagnosis Case Study

This case study documents a simulated incident walkthrough demonstrating how the SmartRetailX observability stack detects, isolates, and diagnoses a critical fault.

---

## Scenario: Order Checkout 500 Error Spike

*   **Symptoms**: Storefront customers report order placement failures (HTTP 500) during a promotional sale.
*   **Root Cause**: Aurora MySQL database connection exhaustion due to a locking spike.

---

## Step 1 — Alert Detection (CloudWatch Alarms)

1.  At **14:05:00 UTC**, traffic spikes on `POST /api/v1/orders`.
2.  The target 5XX count on the ALB breaches the threshold of **10 errors per minute** defined in the CloudWatch alarm:
    *   **Alarm Name**: `smartretailx-high-5xx-errors`
    *   **Metric**: `HTTPCode_Target_5XX_Count` > 10
3.  An automated alert dispatches a notification payload to the SNS topic `smartretailx-notifications-topic-production`, notifying the DevOps on-call engineer.

```
[CLOUDWATCH ALARM STATUS]: ALARM
AlarmName: smartretailx-high-5xx-errors
TriggerTime: 2026-07-31T14:06:00Z
Description: HTTP Target 5XX Error Rate Exceeded
```

---

## Step 2 — Trace Isolation (AWS X-Ray)

The engineer opens the AWS X-Ray Console to analyze the service map and segment details:
1.  The service node map indicates a red error status ring on the **Order Service** node and the **MySQL database** connector node.
2.  Filtering traces by HTTP status `500` reveals that requests on `POST /api/v1/orders` are failing due to a downstream database exception.

### AWS X-Ray Trace Waterfall Representation
```
[Trace ID: 1-5f8f1a2b-7b3c4d5e6f7a8b9c0d1e2f3a]
Segment Name                | Status | Duration | Metrics / Metadata
-------------------------------------------------------------------------------
API Gateway Ingress         |   500  | 5.12 s   | 
  -> ALB Proxy              |   500  | 5.10 s   |
    -> order-service (FastAPI)|   500  | 5.08 s   | DB Connection Timeout
      -> MySQL Query Execution|  ERROR | 5.02 s   | sqlalchemy.exc.TimeoutError
```

*   **Diagnosis**: The X-Ray trace segment reveals that the Order Service spent **5.08 seconds** waiting on the MySQL connector segment before terminating with a timeout, pointing the root cause directly to database connection pool exhaustion.

---

## Step 3 — Log Correlation (`X-Correlation-ID`)

Using the unique `trace_id` and the generated `X-Correlation-ID` parsed from the failing trace, the engineer queries CloudWatch Logs Insights:

```sql
fields @timestamp, @message, log_level, correlation_id
| filter correlation_id = "corr-b12a3456-c78d-90ef-1234-5678abcdef01"
| sort @timestamp asc
```

### Consolidated CloudWatch Log Output
```json
{"timestamp": "2026-07-31T14:05:02.124Z", "correlation_id": "corr-b12a3456-c78d-90ef-1234-5678abcdef01", "level": "INFO", "message": "Received order placement request for product prod-101 (qty: 2)"}
{"timestamp": "2026-07-31T14:05:02.128Z", "correlation_id": "corr-b12a3456-c78d-90ef-1234-5678abcdef01", "level": "INFO", "message": "Attempting database transaction allocation..."}
{"timestamp": "2026-07-31T14:05:07.132Z", "correlation_id": "corr-b12a3456-c78d-90ef-1234-5678abcdef01", "level": "ERROR", "message": "Database checkout transaction failed: sqlalchemy.exc.TimeoutError: QueuePool limit of size 5 overflow 10 reached, connection timed out."}
```

---

## Step 4 — Remediation Action

1.  **Immediate Mitigations**: Increased the Aurora Serverless scaling limits (`max_capacity` from 2.0 to 4.0 ACUs) to support higher connection thread limits.
2.  **Permanent Architecture Fix**: Implemented **Amazon RDS Proxy** between the EKS worker nodes and the database cluster to pool database connections and prevent socket exhaustion.
