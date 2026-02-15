# EKS Deployment Assignment

Production-ready deployment of a Node.js application on Amazon EKS with Terraform, CI/CD, and observability. 

## Architecture

```
                            Internet
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  AWS Cloud (us-east-1)                                                   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  VPC  10.0.0.0/16                                                  │  │
│  │                                                                    │  │
│  │   Internet Gateway                                                 │  │
│  │        │                                                           │  │
│  │   ┌────┴──────────────────┐      ┌─────────────────────────┐      │  │
│  │   │ Public 10.0.0.0/20   │      │ Public 10.0.1.0/20      │      │  │
│  │   │ us-east-1a           │      │ us-east-1b              │      │  │
│  │   │                      │      │                         │      │  │
│  │   │  ┌──────────────┐   │      │  ┌──────────────┐      │      │  │
│  │   │  │     ALB      │   │      │  │  NAT Gateway │      │      │  │
│  │   │  └──────┬───────┘   │      │  └──────────────┘      │      │  │
│  │   │         │           │      │                         │      │  │
│  │   │  ┌──────────────┐   │      │                         │      │  │
│  │   │  │ NAT Gateway  │   │      │                         │      │  │
│  │   │  └──────────────┘   │      │                         │      │  │
│  │   └─────────┼───────────┘      └─────────────────────────┘      │  │
│  │             │                                                    │  │
│  │   ┌─────────┴────────────┐      ┌─────────────────────────┐     │  │
│  │   │ Private 10.0.2.0/20  │      │ Private 10.0.3.0/20     │     │  │
│  │   │ us-east-1a           │      │ us-east-1b              │     │  │
│  │   │                      │      │                         │     │  │
│  │   │  ┌────────────────┐  │      │  ┌────────────────┐    │     │  │
│  │   │  │   EKS Node     │  │      │  │   EKS Node     │    │     │  │
│  │   │  │   (t3.medium)  │  │      │  │   (t3.medium)  │    │     │  │
│  │   │  │                │  │      │  │                │    │     │  │
│  │   │  │  ┌──────────┐  │  │      │  │  ┌──────────┐  │    │     │  │
│  │   │  │  │ App Pods │  │  │      │  │  │ App Pods │  │    │     │  │
│  │   │  │  │ (2 repl) │  │  │      │  │  │ (HPA)    │  │    │     │  │
│  │   │  │  └──────────┘  │  │      │  │  └──────────┘  │    │     │  │
│  │   │  │  ┌──────────┐  │  │      │  │  ┌──────────┐  │    │     │  │
│  │   │  │  │Monitoring│  │  │      │  │  │Fluent Bit│  │    │     │  │
│  │   │  │  │(Prom+Gra)│  │  │      │  │  │(DaemonS) │  │    │     │  │
│  │   │  │  └──────────┘  │  │      │  │  └──────────┘  │    │     │  │
│  │   │  └────────────────┘  │      │  └────────────────┘    │     │  │
│  │   └──────────────────────┘      └─────────────────────────┘     │  │
│  │                                                                  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐  │
│  │ EKS Control Plane│  │       ECR        │  │   CloudWatch Logs     │  │
│  │   (AWS-managed)  │  │ (container imgs) │  │   (via Fluent Bit)    │  │
│  └──────────────────┘  └──────────────────┘  └───────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

GitHub Actions CI/CD:  Build -> Trivy Scan -> Push to ECR -> Deploy to EKS
```

### Key design decisions

- **2 AZs** for high availability; each AZ has a public + private subnet pair
- **EKS nodes in private subnets** with outbound access via NAT gateways
- **ALB** provisioned by the AWS Load Balancer Controller from K8s Ingress resources
- **IRSA** for pod-level AWS access — no static credentials on nodes
- **HPA** scales pods (2-10 replicas) based on CPU/memory utilization
- **Monitoring** runs in-cluster (Prometheus + Grafana); logs forwarded to CloudWatch via Fluent Bit

## Prerequisites

- Terraform >= 1.0
- AWS CLI >= 2.0
- kubectl >= 1.31
- helm >= 3.0
- Docker >= 20.10
- eksctl >= 0.150.0

```bash
export AWS_ACCESS_KEY_ID="<your-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret-key>"
export AWS_DEFAULT_REGION="us-east-1"
```

## Project Structure

```
terraform/              # IaC (modules: vpc, eks, ecr)
app/
  src/index.js          # Node.js Express app
  k8s/                  # K8s manifests (deployment, service, ingress, hpa, etc.)
  Dockerfile            # Multi-stage build
scripts/                # deploy.sh, install-alb-controller.sh, setup-irsa.sh, install-monitoring.sh
monitoring/             # Helm values for Prometheus, Grafana, Fluent Bit
.github/workflows/      # CI/CD pipeline
```

## Quick Start

```bash
git clone <your-repo-url>
cd eks-deployment-assignment
chmod +x scripts/*.sh
./scripts/deploy.sh dev us-east-1
```

Or use `make full-deploy`.

For step-by-step instructions, see [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md).

## Security

- **IRSA** - pods assume IAM roles via service accounts, no static credentials
- **Network Policies** - ingress restricted to ALB controller and monitoring; egress to DNS/HTTPS only
- **Pod Security** - non-root (UID 1001), read-only root filesystem, all capabilities dropped
- **Private subnets** - EKS nodes have no direct internet access
- **Secrets** - sensitive config in Kubernetes Secrets (see `app/k8s/secret.yaml`)

## CI/CD

GitHub Actions pipeline (`.github/workflows/ci-cd.yml`):

1. **Build & Push** - build Docker image, scan with Trivy, push to ECR
2. **Deploy to Dev** - triggered on push to `develop`
3. **Deploy to Prod** - triggered on push to `main`, includes smoke tests

Required GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`

## Monitoring

| Tool       | Access                                                              |
|------------|---------------------------------------------------------------------|
| Prometheus | `kubectl port-forward -n monitoring svc/prometheus-server 9090:80`  |
| Grafana    | `kubectl port-forward -n monitoring svc/grafana 3000:80` (admin/admin123) |
| CloudWatch | `aws logs tail /aws/eks/eks-assignment-dev/containers --follow`     |

Grafana ships with pre-configured dashboards for cluster, node, and pod metrics.

## Cleanup

```bash
kubectl delete namespace eks-assignment
kubectl delete namespace monitoring
helm uninstall aws-load-balancer-controller -n kube-system
cd terraform && terraform destroy -auto-approve
```

## Troubleshooting

```bash
# Pods not starting
kubectl describe pod <pod-name> -n eks-assignment
kubectl logs <pod-name> -n eks-assignment

# Ingress not getting ALB
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Terraform issues
export TF_LOG=DEBUG && terraform apply
```
