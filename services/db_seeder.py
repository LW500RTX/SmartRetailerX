# SmartRetailX Database Seeding & Initialization Script
# Decoupled Seeding for Aurora MySQL (Users/Orders) and DynamoDB (Product Catalog)

import os
import uuid
import json
import hashlib
import pymysql
import boto3
from datetime import datetime

# 1. Database Connection Configuration (MySQL / Aurora)
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_USER = os.getenv("DB_USER", "dbadmin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "dbpassword123")
DB_NAME = os.getenv("DB_NAME", "smartretailx")
DB_PORT = int(os.getenv("DB_PORT", "3306"))

# AWS SDK Configurations (DynamoDB & Secrets Manager)
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL")

boto_args = {"region_name": AWS_REGION}
if AWS_ENDPOINT_URL:
    boto_args["endpoint_url"] = AWS_ENDPOINT_URL
    boto_args["aws_access_key_id"] = "mock"
    boto_args["aws_secret_access_key"] = "mock"

dynamodb = boto3.resource("dynamodb", **boto_args)
secrets_client = boto3.client("secretsmanager", **boto_args)

def get_db_credentials_from_secrets_manager():
    """Retrieve RDS credentials from AWS Secrets Manager if configured."""
    secret_name = os.getenv("DB_SECRET_NAME")
    if not secret_name:
        print("[CONFIG] No Secrets Manager secret configured. Using local environment variables.")
        return DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, DB_PORT

    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_dict = json.loads(response["SecretString"])
        print("[CONFIG] Successfully retrieved database credentials from Secrets Manager.")
        return (
            secret_dict.get("host", DB_HOST),
            secret_dict.get("username", DB_USER),
            secret_dict.get("password", DB_PASSWORD),
            secret_dict.get("dbname", DB_NAME),
            int(secret_dict.get("port", DB_PORT))
        )
    except Exception as e:
        print(f"[WARNING] Secrets Manager lookup failed: {str(e)}. Using fallback env variables.")
        return DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, DB_PORT

def hash_password(password: str) -> str:
    """Helper to generate SHA-256 password hash for users table."""
    return hashlib.sha256(password.encode()).hexdigest()

def seed_aurora_mysql():
    """Seed baseline User and Order transaction database entities."""
    host, user, password, dbname, port = get_db_credentials_from_secrets_manager()
    
    print(f"[AURORA SEED] Connecting to database {dbname} on {host}:{port}...")
    try:
        connection = pymysql.connect(
            host=host,
            user=user,
            password=password,
            database=dbname,
            port=port,
            cursorclass=pymysql.cursors.DictCursor
        )
        with connection.cursor() as cursor:
            # 1. Insert Sample Admin, Store Manager, and Customers
            baseline_users = [
                (str(uuid.uuid4()), "admin@smartretailx.com", hash_password("AdminPass123!"), "admin"),
                (str(uuid.uuid4()), "manager@smartretailx.com", hash_password("ManagerPass123!"), "store_manager"),
                ("customer-001", "lalan@smartretailx.com", hash_password("CustomerPass123!"), "customer")
            ]
            
            # Insert users
            user_sql = "INSERT INTO users (id, email, password_hash, role) VALUES (%s, %s, %s, %s) ON DUPLICATE KEY UPDATE role=VALUES(role)"
            cursor.executemany(user_sql, baseline_users)
            print(f"[AURORA SEED] Successfully seeded {len(baseline_users)} users.")

            # 2. Insert Baseline Order
            order_id = "order-test-001"
            order_sql = """
                INSERT INTO orders (id, customer_id, status, total_amount) 
                VALUES (%s, %s, %s, %s) 
                ON DUPLICATE KEY UPDATE status=VALUES(status)
            """
            cursor.execute(order_sql, (order_id, "customer-001", "Pending", 19.98))
            
            # 3. Insert Baseline Payment for the order
            payment_sql = """
                INSERT INTO payments (id, order_id, transaction_token, status, amount) 
                VALUES (%s, %s, %s, %s, %s) 
                ON DUPLICATE KEY UPDATE status=VALUES(status)
            """
            cursor.execute(payment_sql, (str(uuid.uuid4()), order_id, "tx-mock-seeding-token-99", "APPROVED", 19.98))
            print("[AURORA SEED] Successfully seeded default order and payment records.")
            
            connection.commit()
    except Exception as e:
        print(f"[AURORA ERROR] Failed seeding relational database: {str(e)}")
    finally:
        if 'connection' in locals() and connection.open:
            connection.close()

def seed_dynamodb():
    """Seed baseline catalog products into Amazon DynamoDB table."""
    table_name = os.getenv("DYNAMODB_TABLE", "smartretailx-products-production")
    print(f"[DYNAMODB SEED] Accessing DynamoDB Table: {table_name}...")
    
    try:
        table = dynamodb.Table(table_name)
        
        # Baseline catalog details matching test specs
        baseline_products = [
            {
                "PK": "PRODUCT#prod-101",
                "SK": "METADATA",
                "name": "Organic Red Apples",
                "sku": "APP-001-RED",
                "category": "Produce",
                "price": 4.99,
                "quantity": 75
            },
            {
                "PK": "PRODUCT#prod-102",
                "SK": "METADATA",
                "name": "Whole Milk 2L",
                "sku": "DAI-402-MILK",
                "category": "Dairy",
                "price": 3.50,
                "quantity": 8
            },
            {
                "PK": "PRODUCT#prod-103",
                "SK": "METADATA",
                "name": "Artisan Sourdough",
                "sku": "BAK-990-SOU",
                "category": "Bakery",
                "price": 6.25,
                "quantity": 30
            }
        ]
        
        with table.batch_writer() as batch:
            for product in baseline_products:
                batch.put_item(Item=product)
                
        print(f"[DYNAMODB SEED] Successfully seeded {len(baseline_products)} product catalog items.")
    except Exception as e:
        print(f"[DYNAMODB ERROR] Failed seeding DynamoDB: {str(e)}")

if __name__ == "__main__":
    print("Starting SmartRetailX database initialization and seeding run...")
    seed_aurora_mysql()
    seed_dynamodb()
    print("Database seeding processes complete.")
