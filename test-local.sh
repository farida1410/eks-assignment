#!/bin/bash

# Check if AWS credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: AWS credentials not found!"
    echo "Please set the following environment variables before running this script:"
    echo "  export AWS_ACCESS_KEY_ID='your-access-key'"
    echo "  export AWS_SECRET_ACCESS_KEY='your-secret-key'"
    echo "  export AWS_DEFAULT_REGION='us-east-1'"
    exit 1
fi

echo "Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --name eks-assignment-dev --region ${AWS_DEFAULT_REGION:-us-east-1} > /dev/null 2>&1

echo "Starting port forwarding to EKS application..."
echo "The application will be available at http://localhost:8080"
echo "Press Ctrl+C to stop"
echo ""

kubectl port-forward -n eks-assignment svc/eks-assignment-service 8080:80
