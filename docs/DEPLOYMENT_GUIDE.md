# 🚀 Master Deployment Guide: SmartRetailX (New Laptop & New AWS Account)

---

## 🛠️ Step 1: Install Required Tools on the New Laptop

Install the following software before starting:
1. **Git**: [git-scm.com](https://git-scm.com/)
2. **Docker Desktop**: [docker.com](https://www.docker.com/products/docker-desktop/) *(Ensure Docker Desktop is running)*
3. **Node.js (v18+) & npm**: [nodejs.org](https://nodejs.org/)
4. **Python (v3.10+)**: [python.org](https://www.python.org/)
5. **AWS CLI v2**: [aws.amazon.com/cli/](https://aws.amazon.com/cli/)
6. **Terraform**: [developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads)
7. **kubectl**: [kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)

---

## 🔑 Step 2: Configure AWS CLI Credentials

In your friend's AWS Account:
1. Go to **AWS IAM** → **Users** → Create user (e.g. `SmartRetailX`).
2. Attach policy: `AdministratorAccess`.
3. Go to **Security credentials** → **Create Access Key** → Download `.csv`.

On your **New Laptop Terminal** (PowerShell):

```powershell
aws configure
```
Enter the requested details:
* **AWS Access Key ID**: *(Paste friend's Access Key)*
* **AWS Secret Access Key**: *(Paste friend's Secret Key)*
* **Default region name**: `ap-south-1`
* **Default output format**: `json`

Verify AWS CLI is authenticated:
```powershell
aws sts get-caller-identity
```

---

## 🏗️ Step 3: Provision AWS Cloud Infrastructure via Terraform

Navigate to the `terraform` folder:

```powershell
cd terraform
```

Initialize and apply Terraform:
```powershell
# 1. Initialize providers
terraform init

# 2. Review resources to be created
terraform plan

# 3. Provision AWS Infrastructure (VPC, EKS, Aurora DB, DynamoDB, ECR, EventBridge, SQS, SES, Cognito)
terraform apply --auto-approve
```
> ⏱️ *Note: Infrastructure provisioning takes ~10–15 minutes.*

Display generated outputs:
```powershell
terraform output
```

---

## ☸️ Step 4: Connect `kubectl` to the EKS Cluster & Grant Console Access

1. Update local Kubernetes configuration:
```powershell
aws eks update-kubeconfig --name smartretailx-eks-production --region ap-south-1
```

2. Test cluster nodes:
```powershell
kubectl get nodes
```

3. Grant EKS access to your AWS Console login identity (to view Pods in the AWS Console web interface):
```powershell
$IAM_ARN = (aws sts get-caller-identity --query "Arn" --output text)

aws eks create-access-entry --cluster-name smartretailx-eks-production --principal-arn $IAM_ARN --region ap-south-1

aws eks associate-access-policy --cluster-name smartretailx-eks-production --principal-arn $IAM_ARN --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" --access-scope type=cluster --region ap-south-1
```

---

## 🐳 Step 5: Build and Push Microservice Container Images to Amazon ECR

1. Retrieve AWS Account ID:
```powershell
$ACCOUNT_ID = (aws sts get-caller-identity --query "Account" --output text)
```

2. Log Docker into Amazon ECR:
```powershell
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"
```

3. Build and push all 6 container images:
```powershell
cd ..

# Product Service
docker build -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-product:latest" ./services/product-service
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-product:latest"

# Order Service
docker build -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-order:latest" ./services/order-service
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-order:latest"

# User Service
docker build -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-user:latest" ./services/user-service
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-user:latest"

# Inventory Service
docker build -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-inventory:latest" ./services/inventory-service
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-inventory:latest"

# Notification Service
docker build -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-notification:latest" ./services/notification-service
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-notification:latest"

# Payment Service
docker build -t "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-payment:latest" ./services/payment-service
docker push "$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/smartretailx-payment:latest"
```

---

## 🚢 Step 6: Deploy Kubernetes Manifests to EKS

Deploy all microservices and ingress rules to the EKS cluster:

```powershell
cd k8s
kubectl apply -f .
```

Check running pods & services:
```powershell
kubectl get pods
kubectl get svc
kubectl get ingress
```

---

## 🔐 Step 7: Configure Amazon Cognito & Create Initial User Accounts

1. Get the newly created Cognito User Pool ID from Terraform:
```powershell
cd ../terraform
$POOL_ID = (terraform output -raw cognito_user_pool_id)
$CLIENT_ID = (terraform output -raw cognito_user_pool_client_id)
```

2. Create an **Admin Account** in the new Cognito Pool:
```powershell
aws cognito-idp admin-create-user `
  --user-pool-id $POOL_ID `
  --username "admin@smartretailx.com" `
  --user-attributes Name=email,Value="admin@smartretailx.com" Name=email_verified,Value="true" `
  --message-action SUPPRESS `
  --region ap-south-1

aws cognito-idp admin-set-user-password `
  --user-pool-id $POOL_ID `
  --username "admin@smartretailx.com" `
  --password "SmartRetailXAdmin123!" `
  --permanent `
  --region ap-south-1
```

3. Create a **Customer Account** in the new Cognito Pool:
```powershell
aws cognito-idp admin-create-user `
  --user-pool-id $POOL_ID `
  --username "customer@smartretailx.com" `
  --user-attributes Name=email,Value="customer@smartretailx.com" Name=email_verified,Value="true" `
  --message-action SUPPRESS `
  --region ap-south-1

aws cognito-idp admin-set-user-password `
  --user-pool-id $POOL_ID `
  --username "customer@smartretailx.com" `
  --password "CustomerPass123!" `
  --permanent `
  --region ap-south-1
```

---

## 📩 Step 8: Verify AWS SES Email Address

Because Amazon SES runs in Sandbox mode on new AWS accounts, you must verify your email address to receive order notifications:

```powershell
aws ses verify-email-identity --email-address "lalanweerasooriya@gmail.com" --region ap-south-1
```
> ✉️ *Check your Gmail inbox (`lalanweerasooriya@gmail.com`) and click the verification link sent by AWS SES.*

---

## 🎨 Step 9: Launch Local Microservices & Frontend Dashboard

1. Update `frontend/.env` with your new Cognito keys:
```env
VITE_AWS_REGION=ap-south-1
VITE_COGNITO_USER_POOL_ID=<YOUR_NEW_POOL_ID>
VITE_COGNITO_CLIENT_ID=<YOUR_NEW_CLIENT_ID>
VITE_API_BASE_URL=http://localhost:3000
VITE_ORDER_API_BASE_URL=http://localhost:8000
```

2. Start local microservices via Docker Compose (optional for local testing):
```powershell
cd ..
docker-compose up --build -d
```

3. Start the Frontend React application:
```powershell
cd frontend
npm install
npm run dev
```

---

## 🎉 Step 10: Access Your Platform

1. Open your browser: `http://localhost:5173`
2. Click **Login** and sign in with:
   - **Username**: `admin@smartretailx.com`
   - **Password**: `SmartRetailXAdmin123!`
3. Place an order or schedule a flash sale promotion!
