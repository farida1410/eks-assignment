# CI/CD Pipeline

GitHub Actions workflow (`ci-cd.yml`) that builds, tests, and deploys to EKS.

## Pipeline

```
Code Push -> Build & Test -> Build Docker Image -> Push to ECR -> Deploy to EKS -> Health Check
```

**Triggers:**
- Push to `main` (with changes in `app/**` or `.github/workflows/**`): full deploy
- PRs to `main`: build & test only

## Setup

Add these GitHub Secrets (Settings > Secrets and variables > Actions):

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key with ECR + EKS permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |

Make sure the ECR repo and EKS cluster exist:

```bash
aws ecr describe-repositories --repository-names eks-assignment-app --region us-east-1
aws eks describe-cluster --name eks-assignment-dev --region us-east-1
```

## Jobs

**Build and Test** - checkout, setup Node.js 18, install deps, run tests/lint. Runs on every push and PR.

**Build and Push Docker Image** - build with BuildKit, push to ECR. Tags: `latest`, `main-<sha>`, `<branch>`. Only on push to `main`.

**Deploy to EKS** - update kubeconfig, apply K8s manifests, wait for rollout (5min timeout). Only after successful build.

**Health Check** - port-forward to service, test `/health` and `/` endpoints. Only after successful deploy.

## Troubleshooting

**Build fails:** run `cd app && npm install && npm test` locally.

**ECR push fails:** check AWS credentials and that the repo exists (`aws ecr describe-repositories --repository-names eks-assignment-app`).

**Deploy fails:** check `kubectl get pods -n eks-assignment` and `kubectl describe pod <pod> -n eks-assignment`.

## Required IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    }
  ]
}
```

## Rollback

```bash
kubectl rollout undo deployment/eks-assignment-app -n eks-assignment
```
