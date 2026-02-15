# Deployment Guide

## Prerequisites

```bash
terraform --version    # >= 1.0
aws --version         # >= 2.0
kubectl version       # >= 1.28
helm version          # >= 3.0
eksctl version        # >= 0.150.0
docker --version      # >= 20.10
```

```bash
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_DEFAULT_REGION="us-east-1"
aws sts get-caller-identity  # verify
```

## Option A: Automated

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh dev us-east-1
```

Takes ~20-30 minutes. Or use `make full-deploy`.

## Option B: Step by Step

### 1. Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-assignment-dev
kubectl get nodes
```

### 3. ALB Controller + IRSA

```bash
cd ../scripts
./install-alb-controller.sh eks-assignment-dev us-east-1
./setup-irsa.sh eks-assignment-dev us-east-1
```

### 4. Update manifests with your account ID

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
cd ../app/k8s
sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" deployment.yaml
sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" serviceaccount.yaml
```

### 5. Build and push Docker image

```bash
cd ../..
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REPO%%/*}
cd app
docker build -t $ECR_REPO:latest .
docker push $ECR_REPO:latest
```

### 6. Deploy to Kubernetes

```bash
cd k8s
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f network-policy.yaml
kubectl apply -f hpa.yaml
kubectl get all -n eks-assignment
```

### 7. Install monitoring

```bash
cd ../../scripts
./install-monitoring.sh eks-assignment-dev us-east-1
```

## Verify

```bash
# Wait a couple minutes for ALB provisioning
INGRESS_URL=$(kubectl get ingress eks-assignment-ingress -n eks-assignment -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$INGRESS_URL
curl http://$INGRESS_URL/health
curl http://$INGRESS_URL/api/info
```

Monitoring access:

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80    # Prometheus
kubectl port-forward -n monitoring svc/grafana 3000:80              # Grafana (admin/admin123)
aws logs tail /aws/eks/eks-assignment-dev/containers --follow       # CloudWatch
```

## CI/CD

Push to `develop` to deploy to dev, push to `main` to deploy to prod:

```bash
git checkout -b develop
git push origin develop
```

## Cleanup

```bash
kubectl delete namespace eks-assignment
kubectl delete namespace monitoring
helm uninstall aws-load-balancer-controller -n kube-system
cd terraform && terraform destroy -auto-approve
```

## Troubleshooting

**Pods crashing:** `kubectl describe pod <pod> -n eks-assignment` and `kubectl logs <pod> -n eks-assignment`

**Ingress not provisioning:** `kubectl logs -n kube-system deployment/aws-load-balancer-controller`

**Terraform errors:** `export TF_LOG=DEBUG` then re-run

**ECR push fails:** re-authenticate with `aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com`
