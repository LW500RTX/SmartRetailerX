#!/bin/bash

# Configuration
API_URL=${API_URL:-"http://localhost"}
OUTPUT_DIR="results"
mkdir -p $OUTPUT_DIR

echo "================================================================="
echo "           SmartRetailX Load Test Runner (k6)"
echo "Target Endpoint: $API_URL"
echo "================================================================="

# Check if k6 is installed
if ! command -v k6 &> /dev/null
then
    echo "ERROR: k6 is not installed. Please install k6 from https://k6.io"
    exit 1
fi

echo "Starting load test..."
# Run k6 and output JSON metrics
k6 run \
  --env API_URL=$API_URL \
  --summary-export=$OUTPUT_DIR/summary.json \
  load_test.js

echo "Load test execution completed."
echo "Results exported to: $OUTPUT_DIR/summary.json"
echo "================================================================="
