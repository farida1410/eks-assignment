#!/bin/bash
set -e

# This script installs the AWS Load Balancer Controller on EKS

CLUSTER_NAME=${1:-"eks-assignment-dev"}
AWS_REGION=${2:-"us-east-1"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo "Installing AWS Load Balancer Controller for cluster: $CLUSTER_NAME"

# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Create IAM policy for AWS Load Balancer Controller
echo "Creating IAM policy for AWS Load Balancer Controller..."
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json \
    --region $AWS_REGION 2>/dev/null || echo "Policy already exists"

rm -f iam-policy.json

# Create IAM role for service account
echo "Creating IAM role for service account..."
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=$AWS_REGION \
  --override-existing-serviceaccounts

# Add EKS chart repo
echo "Adding EKS Helm chart repository..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

echo "AWS Load Balancer Controller installed successfully!"
kubectl get deployment -n kube-system aws-load-balancer-controller
