# SmartRetailX DynamoDB Product Catalogue Seeder Script
# Target: Amazon DynamoDB Table "smartretailx-products-production"

import os
import boto3

# AWS SDK Configurations
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL")

boto_args = {"region_name": AWS_REGION}
if AWS_ENDPOINT_URL:
    boto_args["endpoint_url"] = AWS_ENDPOINT_URL
    boto_args["aws_access_key_id"] = "mock"
    boto_args["aws_secret_access_key"] = "mock"

dynamodb = boto3.resource("dynamodb", **boto_args)

def seed_products():
    table_name = os.getenv("DYNAMODB_TABLE", "smartretailx-products-production")
    print(f"[DYNAMODB] Connecting to table: {table_name}...")
    
    try:
        table = dynamodb.Table(table_name)
        
        # 6 Baseline retail catalogue items with matching schemas
        products = [
            {
                "PK": "PRODUCT#prod-201",
                "SK": "METADATA",
                "name": "Smart Watch Series 5",
                "product_name": "Smart Watch Series 5",
                "sku": "WAT-501-SMART",
                "category": "Electronics",
                "price": 199.99,
                "quantity": 50,
                "stock_level": 50,
                "image_url": "https://smartretailx-product-images-production.s3.ap-south-1.amazonaws.com/products/smart_watch.png"
            },
            {
                "PK": "PRODUCT#prod-202",
                "SK": "METADATA",
                "name": "Wireless Earbuds Pro",
                "product_name": "Wireless Earbuds Pro",
                "sku": "EAR-990-WIRELESS",
                "category": "Electronics",
                "price": 89.50,
                "quantity": 120,
                "stock_level": 120,
                "image_url": "https://smartretailx-product-images-production.s3.ap-south-1.amazonaws.com/products/earbuds.png"
            },
            {
                "PK": "PRODUCT#prod-203",
                "SK": "METADATA",
                "name": "Ultra HD Monitor 27inch",
                "product_name": "Ultra HD Monitor 27inch",
                "sku": "MON-270-UHD",
                "category": "Electronics",
                "price": 349.99,
                "quantity": 25,
                "stock_level": 25,
                "image_url": "https://smartretailx-product-images-production.s3.ap-south-1.amazonaws.com/products/monitor.png"
            },
            {
                "PK": "PRODUCT#prod-204",
                "SK": "METADATA",
                "name": "Ergonomic Mechanical Keyboard",
                "product_name": "Ergonomic Mechanical Keyboard",
                "sku": "KEY-104-ERGO",
                "category": "Office",
                "price": 129.99,
                "quantity": 40,
                "stock_level": 40,
                "image_url": "https://smartretailx-product-images-production.s3.ap-south-1.amazonaws.com/products/keyboard.png"
            },
            {
                "PK": "PRODUCT#prod-205",
                "SK": "METADATA",
                "name": "Precision Gaming Mouse",
                "product_name": "Precision Gaming Mouse",
                "sku": "MOU-880-GAMING",
                "category": "Office",
                "price": 59.99,
                "quantity": 70,
                "stock_level": 70,
                "image_url": "https://smartretailx-product-images-production.s3.ap-south-1.amazonaws.com/products/mouse.png"
            },
            {
                "PK": "PRODUCT#prod-206",
                "SK": "METADATA",
                "name": "Multi-Port USB-C Hub",
                "product_name": "Multi-Port USB-C Hub",
                "sku": "HUB-006-USBC",
                "category": "Accessories",
                "price": 45.00,
                "quantity": 150,
                "stock_level": 150,
                "image_url": "https://smartretailx-product-images-production.s3.ap-south-1.amazonaws.com/products/usb_hub.png"
            }
        ]
        
        with table.batch_writer() as batch:
            for item in products:
                # DynamoDB JSON serialization float conversion helper
                # Decimal type is used in boto3 for numbers, convert float to string or Decimal
                # We can import Decimal or pass float directly (boto3 allows float for DynamoDB if configured)
                # But Decimal is safer, let's use Decimal
                from decimal import Decimal
                item_decimal = {
                    k: Decimal(str(v)) if isinstance(v, (float, int)) and k in ["price", "quantity", "stock_level"] else v
                    for k, v in item.items()
                }
                batch.put_item(Item=item_decimal)
                
        print(f"[DYNAMODB] Successfully populated {len(products)} products catalog items.")
    except Exception as e:
        print(f"[DYNAMODB ERROR] Failed to batch write: {str(e)}")

if __name__ == "__main__":
    print("Initializing DynamoDB catalog seeding...")
    seed_products()
