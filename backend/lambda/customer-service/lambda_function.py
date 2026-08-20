import json
import os
import boto3
import pymysql
import hashlib

secrets = boto3.client("secretsmanager")

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

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

def lambda_handler(event, context):
    request_context = event.get("requestContext", {}).get("http", {})
    method = request_context.get("method", "GET")
    path = event.get("rawPath", "/")

    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
    }

    if method == "OPTIONS":
        return {"statusCode": 200, "headers": headers, "body": json.dumps("OK")}

    try:
        try:
            conn = get_db()
        except Exception as db_e:
            return {"statusCode": 500, "headers": headers, "body": json.dumps({"error": f"Database connection failed: {str(db_e)}"})}
            
        with conn.cursor() as cur:
            # Auto-repair / schema initialization
            try:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS customers (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        email VARCHAR(255) NOT NULL UNIQUE,
                        phone VARCHAR(50),
                        password VARCHAR(255) NOT NULL,
                        role VARCHAR(20) DEFAULT 'customer'
                    )
                """)
            except Exception as e:
                print(f"Error creating customers table: {e}")

            # --- ROUTE: /login ---
            if path == "/login" and method == "POST":
                body = json.loads(event.get("body", "{}"))
                email = body.get("email")
                password = body.get("password")
                
                if not email or not password:
                    return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "Email and password are required"})}

                cur.execute("SELECT name, role, password FROM customers WHERE email = %s LIMIT 1", (email,))
                user_record = cur.fetchone()
                
                if not user_record:
                    return {"statusCode": 401, "headers": headers, "body": json.dumps({"error": "Invalid email or password"})}
                    
                stored_password = user_record.get('password')
                hashed_input = hash_password(password)

                if stored_password != hashed_input:
                    return {"statusCode": 401, "headers": headers, "body": json.dumps({"error": "Invalid email or password"})}
                    
                role = user_record.get('role') or "customer"
                name = user_record.get('name', 'Customer')
                
                return {"statusCode": 200, "headers": headers, "body": json.dumps({
                    "status": "success",
                    "token": "mock-jwt-token-123", 
                    "user": email,
                    "name": name,
                    "role": role
                })}

            # --- ROUTE: /register ---
            elif path == "/register" and method == "POST":
                body = json.loads(event.get("body", "{}"))
                name = body.get("name", "New User")
                email = body.get("email")
                password = body.get("password", "defaultpassword")
                phone = body.get("phone", "")
                
                if not email or not password:
                    return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "Email and password are required"})}
                
                # All registrations default to standard customer role, no hardcoded bypasses
                role = "customer"
                hashed_pw = hash_password(password)
                    
                try:
                    cur.execute(
                        "INSERT INTO customers (name, email, phone, password, role) VALUES (%s, %s, %s, %s, %s)",
                        (name, email, phone, hashed_pw, role),
                    )
                    return {"statusCode": 201, "headers": headers, "body": json.dumps({"message": "User registered successfully"})}
                except Exception as e:
                    print(f"Error registering user: {e}")
                    if "Duplicate entry" in str(e):
                        return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "Email already exists"})}
                    return {"statusCode": 500, "headers": headers, "body": json.dumps({"error": f"Failed to register user: {str(e)}"})}

            # --- ROUTE: /customers ---
            elif path == "/customers":
                if method == "GET":
                    # Explicitly select attributes; NEVER return password column
                    cur.execute("SELECT id, name, email, phone, role FROM customers ORDER BY id DESC LIMIT 50")
                    rows = cur.fetchall()
                    return {"statusCode": 200, "headers": headers, "body": json.dumps(rows, default=str)}

                elif method == "POST":
                    body = json.loads(event.get("body", "{}"))
                    name = body.get("name")
                    email = body.get("email")
                    phone = body.get("phone")
                    password = body.get("password", "defaultpassword")
                    hashed_pw = hash_password(password)
                    
                    if not email:
                        return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "Email is required"})}

                    try:
                        cur.execute(
                            "INSERT INTO customers (name, email, phone, password, role) VALUES (%s, %s, %s, %s, 'customer')",
                            (name, email, phone, hashed_pw),
                        )
                        return {"statusCode": 201, "headers": headers, "body": json.dumps({"message": "created"})}
                    except Exception as e:
                        if "Duplicate entry" in str(e):
                            return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "Email already exists"})}
                        return {"statusCode": 500, "headers": headers, "body": json.dumps({"error": str(e)})}

        return {"statusCode": 404, "headers": headers, "body": json.dumps({"error": "Not Found"})}
    
    except Exception as e:
        print("Error in customer service lambda:", str(e))
        return {"statusCode": 500, "headers": headers, "body": json.dumps({"error": str(e)})}
    
    finally:
        if 'conn' in locals() and conn.open:
            conn.close()