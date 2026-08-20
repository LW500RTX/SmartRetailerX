"""
SmartRetailX — Two-Phase Commit (2PC) Distributed Transaction & Rollback Simulator
Simulates:
  1. Successful 2PC Global Commit
  2. Simulated 2PC VOTE_ABORT & Full Database Rollback Data Consistency Test
Outputs structured JSON logs to container console (stdout).
"""

import json
import time
import uuid
import sys
import argparse
from datetime import datetime, timezone

def log_event(phase, status, service, tx_id, detail="", level="INFO"):
    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "tx_id": tx_id,
        "protocol": "2PC",
        "phase": phase,
        "service": service,
        "status": status,
        "message": detail
    }
    print(json.dumps(log_entry, indent=2))
    sys.stdout.flush()

def run_2pc_commit_test():
    tx_id = f"tx-commit-{uuid.uuid4().hex[:8]}"
    print("=" * 75)
    print(f"  SCENARIO 1: TWO-PHASE COMMIT (2PC) GLOBAL COMMIT SUCCESS: {tx_id}")
    print("=" * 75)
    
    log_event("PHASE_1_PREPARE", "INITIATED", "coordinator", tx_id, "Coordinator sent PREPARE request to all participants")
    time.sleep(0.1)
    
    # 1. Order Service Vote
    log_event("PHASE_1_PREPARE", "PREPARING", "order-service", tx_id, "Validating order schema & acquiring database write lock")
    log_event("PHASE_1_VOTING", "VOTE_COMMIT", "order-service", tx_id, "Order service voted VOTE_COMMIT")
    
    # 2. Payment Service Vote
    log_event("PHASE_1_PREPARE", "PREPARING", "payment-service", tx_id, "Pre-authorizing wallet balance")
    log_event("PHASE_1_VOTING", "VOTE_COMMIT", "payment-service", tx_id, "Payment service voted VOTE_COMMIT")
    
    # 3. Inventory Service Vote
    log_event("PHASE_1_PREPARE", "PREPARING", "inventory-service", tx_id, "Reserving SKU stock count in DynamoDB")
    log_event("PHASE_1_VOTING", "VOTE_COMMIT", "inventory-service", tx_id, "Inventory service voted VOTE_COMMIT")
    
    # Phase 2 Decision
    log_event("PHASE_2_DECISION", "GLOBAL_COMMIT", "coordinator", tx_id, "All participants voted VOTE_COMMIT. Issuing GLOBAL_COMMIT")
    
    for participant in ["order-service", "payment-service", "inventory-service"]:
        log_event("PHASE_2_COMMIT", "COMMITTING", participant, tx_id, f"Persisting transaction records in {participant}")
        log_event("PHASE_2_FINAL", "COMMIT_SUCCESS", participant, tx_id, f"{participant} committed successfully")
        
    log_event("TRANSACTION_COMPLETE", "SUCCESS", "coordinator", tx_id, "Distributed 2PC transaction finalized cleanly")
    print("=" * 75 + "\n")

def run_2pc_rollback_test():
    tx_id = f"tx-rollback-{uuid.uuid4().hex[:8]}"
    print("=" * 75)
    print(f"  SCENARIO 2: SIMULATED ROLLBACK & DATA CONSISTENCY TEST: {tx_id}")
    print("=" * 75)
    
    log_event("PHASE_1_PREPARE", "INITIATED", "coordinator", tx_id, "Coordinator sent PREPARE request to all participants")
    time.sleep(0.1)
    
    # 1. Order Service Vote -> Commit
    log_event("PHASE_1_PREPARE", "PREPARING", "order-service", tx_id, "Acquiring pending order lock")
    log_event("PHASE_1_VOTING", "VOTE_COMMIT", "order-service", tx_id, "Order service voted VOTE_COMMIT (Pending order row locked)")
    
    # 2. Payment Service Vote -> ABORT (Insufficient Funds)
    log_event("PHASE_1_PREPARE", "PREPARING", "payment-service", tx_id, "Verifying credit card authorization & balance")
    log_event("PHASE_1_VOTING", "VOTE_ABORT", "payment-service", tx_id, "Payment service voted VOTE_ABORT (Error: Insufficient customer funds)", level="WARN")
    
    # 3. Inventory Service Vote -> Aborted
    log_event("PHASE_1_PREPARE", "CANCELLED", "inventory-service", tx_id, "Skipping prepare step due to early participant VOTE_ABORT")
    
    # Phase 2 Rollback Decision
    log_event("PHASE_2_DECISION", "GLOBAL_ABORT", "coordinator", tx_id, "Participant 'payment-service' rejected transaction. Triggering GLOBAL_ABORT", level="WARN")
    time.sleep(0.2)
    
    # Rollback execution across all participants
    log_event("PHASE_2_ROLLBACK", "ROLLING_BACK", "order-service", tx_id, "Rolling back pending order row & releasing database locks")
    log_event("PHASE_2_ROLLBACK", "ROLLBACK_SUCCESS", "order-service", tx_id, "Order service state restored to pre-transaction baseline")
    
    log_event("PHASE_2_ROLLBACK", "ROLLING_BACK", "payment-service", tx_id, "Releasing payment reservation & clearing session token")
    log_event("PHASE_2_ROLLBACK", "ROLLBACK_SUCCESS", "payment-service", tx_id, "Payment service state restored to pre-transaction baseline")
    
    log_event("PHASE_2_ROLLBACK", "ROLLING_BACK", "inventory-service", tx_id, "Releasing DynamoDB stock allocation lock")
    log_event("PHASE_2_ROLLBACK", "ROLLBACK_SUCCESS", "inventory-service", tx_id, "Inventory service stock levels verified unchanged")
    
    # Data Consistency Verification Check
    log_event("CONSISTENCY_CHECK", "VERIFIED", "coordinator", tx_id, "Data consistency check passed across distributed tables: 0 orphan records, 100% state restored")
    log_event("TRANSACTION_COMPLETE", "ABORTED_CLEANLY", "coordinator", tx_id, "2PC Distributed Rollback test completed successfully")
    print("=" * 75 + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="2PC Simulator")
    parser.add_argument("--mode", choices=["commit", "rollback", "both"], default="both", help="Test mode to execute")
    args = parser.parse_args()

    if args.mode in ["commit", "both"]:
        run_2pc_commit_test()
    if args.mode in ["rollback", "both"]:
        run_2pc_rollback_test()
