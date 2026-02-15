#!/bin/bash
set -e

# This script sets up IRSA (IAM Roles for Service Accounts) for the application

CLUSTER_NAME=${1:-"eks-assignment-dev"}
AWS_REGION=${2:-"us-east-1"}
NAMESPACE="eks-assignment"
SERVICE_ACCOUNT="eks-assignment-sa"
ROLE_NAME="eks-assignment-app-role"

echo "Setting up IRSA for application..."

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Get OIDC provider URL
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

echo "OIDC Provider: $OIDC_PROVIDER"

# Create IAM policy for the application
cat > app-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:*"
      ]
    }
  ]
}
EOF

# Create the policy
aws iam create-policy \
    --policy-name ${ROLE_NAME}-policy \
    --policy-document file://app-policy.json \
    --region $AWS_REGION 2>/dev/null || echo "Policy already exists"

rm -f app-policy.json

# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "IAM role for EKS assignment application" 2>/dev/null || echo "Role already exists"

rm -f trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${ROLE_NAME}-policy

echo "IRSA setup completed successfully!"
echo "Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "Update the serviceaccount.yaml with this role ARN:"
echo "  annotations:"
echo "    eks.amazonaws.com/role-arn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
