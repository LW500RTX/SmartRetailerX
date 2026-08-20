import boto3
import json
import time
import random
from datetime import datetime

iot_client = boto3.client('iot-data', region_name='ap-south-1')

TOPIC = "aquasense/telemetry"
METER_ID = "home-meter-001"

print(f"Starting AquaSense IoT Simulation for {METER_ID}...")
print(f"Publishing to topic: {TOPIC}")
print("Press Ctrl+C to stop.\n")

try:
    while True:
        water_flow = round(random.uniform(10.0, 25.0), 1)
        energy_usage = round(random.uniform(5.0, 15.0), 1)
        status = "alert" if random.random() > 0.95 else "normal"

        payload = {
            "meter_id": METER_ID,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "water_flow": water_flow,
            "energy_usage": energy_usage,
            "status": status
        }

        iot_client.publish(
            topic=TOPIC,
            qos=1,
            payload=json.dumps(payload)
        )

        print(f"[OPERATIONAL] Sending Telemetry: {json.dumps(payload)}")
        time.sleep(5)

except KeyboardInterrupt:
    print("\nSimulation stopped.")
except Exception as e:
    print(f"\nError: {e}")
