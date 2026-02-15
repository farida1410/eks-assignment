#!/bin/bash
set -e

# Main deployment script for EKS Assignment

ENVIRONMENT=${1:-"dev"}
AWS_REGION=${2:-"us-east-1"}

echo "=========================================="
echo "EKS Assignment Deployment Script"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "=========================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "Checking prerequisites..."
for cmd in terraform aws kubectl helm eksctl docker; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is not installed. Please install it first."
        exit 1
    fi
done

echo "All prerequisites are installed."

# Step 1: Deploy Infrastructure with Terraform
echo ""
echo "Step 1: Deploying infrastructure with Terraform..."
cd terraform
terraform init
terraform validate
terraform plan -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION"

read -p "Do you want to apply this Terraform plan? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

terraform apply -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -auto-approve

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo "Cluster Name: $CLUSTER_NAME"
echo "ECR Repository: $ECR_REPOSITORY_URL"

cd ..

# Step 2: Configure kubectl
echo ""
echo "Step 2: Configuring kubectl..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Step 3: Install AWS Load Balancer Controller
echo ""
echo "Step 3: Installing AWS Load Balancer Controller..."
bash scripts/install-alb-controller.sh $CLUSTER_NAME $AWS_REGION

# Step 4: Setup IRSA for application
echo ""
echo "Step 4: Setting up IRSA for application..."
bash scripts/setup-irsa.sh $CLUSTER_NAME $AWS_REGION

# Update serviceaccount.yaml with correct role ARN
sed -i.bak "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" app/k8s/serviceaccount.yaml

# Step 5: Build and push Docker image
echo ""
echo "Step 5: Building and pushing Docker image..."
cd app

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push
docker build -t $ECR_REPOSITORY_URL:latest .
docker push $ECR_REPOSITORY_URL:latest

cd ..

# Update deployment.yaml with correct image
sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" app/k8s/deployment.yaml

# Step 6: Deploy application to Kubernetes
echo ""
echo "Step 6: Deploying application to Kubernetes..."
kubectl apply -f app/k8s/namespace.yaml
kubectl apply -f app/k8s/secret.yaml
kubectl apply -f app/k8s/serviceaccount.yaml
kubectl apply -f app/k8s/deployment.yaml
kubectl apply -f app/k8s/service.yaml
kubectl apply -f app/k8s/ingress.yaml
kubectl apply -f app/k8s/network-policy.yaml
kubectl apply -f app/k8s/hpa.yaml

# Step 7: Install monitoring stack
echo ""
echo "Step 7: Installing monitoring stack..."
bash scripts/install-monitoring.sh $CLUSTER_NAME $AWS_REGION

# Wait for deployment to be ready
echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/eks-assignment-app -n eks-assignment

# Get application URL
echo ""
echo "=========================================="
echo "Deployment completed successfully!"
echo "=========================================="
echo ""
kubectl get all -n eks-assignment
echo ""
echo "Application Ingress:"
kubectl get ingress -n eks-assignment
echo ""
echo "To access the application, wait a few minutes for the ALB to be provisioned, then use:"
echo "  INGRESS_URL=\$(kubectl get ingress eks-assignment-ingress -n eks-assignment -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "  curl http://\$INGRESS_URL"
echo ""
echo "To access Grafana:"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "  Open: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
