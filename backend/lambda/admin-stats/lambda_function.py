import json
import os
import boto3
import pymysql

secrets = boto3.client("secretsmanager")
dynamodb = boto3.resource("dynamodb")

def get_db():
    secret_name = os.environ["SECRET_NAME"]
    res = secrets.get_secret_value(SecretId=secret_name)
    cfg = json.loads(res["SecretString"])

    conn = pymysql.connect(
        host=cfg["host"],
        user=cfg["username"],
        password=cfg["password"],
        database=cfg["database"],
        port=int(cfg["port"]),
        connect_timeout=5,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )
    return conn

def lambda_handler(event, context):
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
    }

    request_context = event.get("requestContext", {}).get("http", {})
    method = request_context.get("method", "GET")

    if method == "OPTIONS":
        return {"statusCode": 200, "headers": headers, "body": json.dumps("OK")}

    try:
        # 1. Fetch Retail Metrics from RDS MySQL
        total_revenue = 0.0
        total_orders = 0
        try:
            conn = get_db()
            with conn.cursor() as cur:
                # Calculate total revenue and total orders
                cur.execute("SELECT SUM(total_amount) as revenue, COUNT(*) as count FROM orders")
                result = cur.fetchone()
                if result:
                    total_revenue = float(result.get('revenue') or 0.0)
                    total_orders = int(result.get('count') or 0)
            conn.close()
        except Exception as db_e:
            print(f"Database error querying orders: {str(db_e)}")

        # 2. Fetch Product Catalogue Count from DynamoDB
        product_count = 0
        try:
            table_name = os.environ.get("DYNAMODB_TABLE")
            table = dynamodb.Table(table_name)
            
            response = table.scan()
            items = response.get('Items', [])
            while 'LastEvaluatedKey' in response:
                response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
                items.extend(response.get('Items', []))
            
            # Filter and count product items
            product_count = len([
                i for i in items 
                if str(i.get('PK', '')).startswith('PRODUCT#') and i.get('SK') == 'METADATA'
            ])
        except Exception as ddb_e:
            print(f"DynamoDB error scanning products: {str(ddb_e)}")

        stats = {
            "total_revenue": round(total_revenue, 2),
            "total_orders": total_orders,
            "product_count": product_count
        }

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps(stats)
        }

    except Exception as e:
        print(f"Error executing admin statistics: {str(e)}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
