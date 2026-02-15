#!/bin/bash
set -e

# This script installs the observability stack (Prometheus, Grafana, Fluent Bit)

CLUSTER_NAME=${1:-"eks-assignment-dev"}
AWS_REGION=${2:-"us-east-1"}

echo "Installing observability stack on cluster: $CLUSTER_NAME"

# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring name=monitoring --overwrite

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Install Prometheus
echo "Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values ../monitoring/prometheus-values.yaml \
  --wait

# Install Grafana
echo "Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values ../monitoring/grafana-values.yaml \
  --wait

# Install Fluent Bit
echo "Installing Fluent Bit..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create IAM policy for Fluent Bit
cat > fluent-bit-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
    --policy-name FluentBitCloudWatchPolicy \
    --policy-document file://fluent-bit-policy.json \
    --region $AWS_REGION 2>/dev/null || echo "Policy already exists"

rm -f fluent-bit-policy.json

# Create IRSA for Fluent Bit
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=monitoring \
  --name=fluent-bit \
  --role-name fluent-bit-role \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/FluentBitCloudWatchPolicy \
  --approve \
  --region=$AWS_REGION \
  --override-existing-serviceaccounts || echo "Service account already exists"

# Update fluent-bit-values.yaml with account ID
sed -i.bak "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" ../monitoring/fluent-bit-values.yaml

helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  --values ../monitoring/fluent-bit-values.yaml \
  --wait

# Restore original file
mv ../monitoring/fluent-bit-values.yaml.bak ../monitoring/fluent-bit-values.yaml

echo ""
echo "Observability stack installed successfully!"
echo ""
echo "Prometheus URL: kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
echo "Grafana URL: kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "Grafana Admin Password: kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 --decode"
echo ""
echo "To access Grafana:"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "  Open: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
