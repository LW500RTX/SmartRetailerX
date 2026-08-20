# SmartRetailX Consolidated Seeding Orchestrator
import subprocess
import sys
import os

def run_seeder(script_name):
    script_path = os.path.join(os.path.dirname(__file__), script_name)
    print(f"==================================================")
    print(f"Executing: {script_name}...")
    print(f"==================================================")
    try:
        result = subprocess.run([sys.executable, script_path], check=True)
        print(f"Execution of {script_name} completed successfully.\n")
    except subprocess.CalledProcessError as e:
        print(f"Error executing {script_name}: {str(e)}\n")

if __name__ == "__main__":
    print("Starting quality data seeding run for SmartRetailX...")
    
    # 1. Seed DynamoDB Products Catalog
    run_seeder("seed_dynamodb.py")
    
    # 2. Seed Relational Schema (Aurora MySQL)
    # The database seeder contains the connection credentials validation
    run_seeder("db_seeder.py")
    
    print("Consolidated database seeding run complete.")
