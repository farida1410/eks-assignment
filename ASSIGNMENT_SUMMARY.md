# Assignment Summary

## Part 1: Infrastructure

VPC with 2 public + 2 private subnets across 2 AZs, EKS cluster in private subnets, managed node group (t3.medium, 1-4 nodes auto-scaling), IRSA enabled via OIDC provider. All provisioned with Terraform using a modular structure (`terraform/modules/vpc`, `eks`, `ecr`).

## Part 2: Application Deployment

Node.js REST API with endpoints: `/`, `/health`, `/ready`, `/api/info`. Multi-stage Dockerfile pushed to ECR. Kubernetes manifests cover: Deployment (2 replicas, HPA 2-10), ClusterIP Service, ALB Ingress, NetworkPolicy, ServiceAccount with IRSA, Secrets.

Pod security: non-root user (1001), read-only root filesystem, all capabilities dropped, resource requests/limits set.

## Part 3: Security

- IRSA for AWS API access (no static credentials)
- Network policies: ingress from ALB + monitoring only, egress to DNS/HTTPS only
- EKS nodes in private subnets
- Pod security context (non-root, read-only fs, drop ALL capabilities)
- ECR image scanning on push, encrypted repository

## Part 4: CI/CD

GitHub Actions pipeline (`ci-cd.yml`):
- Build Docker image and scan with Trivy
- Push to ECR with commit SHA + latest tags
- Deploy to dev on `develop` push, prod on `main` push
- Rollout verification and smoke tests

## Part 5: Observability

- **Prometheus** - metrics collection from K8s API, nodes, pods (10Gi persistent storage)
- **Grafana** - pre-configured dashboards (cluster, pods, node exporter), admin/admin123
- **Fluent Bit** - log aggregation to CloudWatch (`/aws/eks/eks-assignment-dev/containers`)

All installed via Helm, see `monitoring/` for values files and `scripts/install-monitoring.sh`.

## Requirements Checklist

### Infrastructure
- [x] VPC with 2 public + 2 private subnets
- [x] EKS cluster in private subnets
- [x] Managed Node Group
- [x] IRSA enabled
- [x] Terraform

### Application
- [x] Sample application (Node.js REST API)
- [x] Dockerfile
- [x] Push image to ECR
- [x] Deployment, Service (ClusterIP), Ingress (ALB)

### Security
- [x] IRSA
- [x] Network Policies
- [x] Restricted public access
- [x] Kubernetes Secrets
- [x] Pod Security Standards

### CI/CD
- [x] GitHub Actions pipeline
- [x] Build, push to ECR, deploy to EKS
- [x] Multi-environment support (dev/prod)

### Observability
- [x] Prometheus
- [x] Grafana
- [x] Fluent Bit / CloudWatch

## Quick Start

```bash
git clone <your-repo-url>
cd eks-deployment-assignment
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
./scripts/deploy.sh dev us-east-1
```

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed steps.
