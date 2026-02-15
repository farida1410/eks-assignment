.PHONY: help init plan apply destroy build push deploy clean

CLUSTER_NAME ?= eks-assignment-dev
AWS_REGION ?= us-east-1
ENVIRONMENT ?= dev

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	cd terraform && terraform init

validate: ## Validate Terraform configuration
	cd terraform && terraform validate

plan: ## Plan Terraform changes
	cd terraform && terraform plan -var="environment=$(ENVIRONMENT)" -var="aws_region=$(AWS_REGION)"

apply: ## Apply Terraform configuration
	cd terraform && terraform apply -var="environment=$(ENVIRONMENT)" -var="aws_region=$(AWS_REGION)" -auto-approve

destroy: ## Destroy Terraform infrastructure
	cd terraform && terraform destroy -var="environment=$(ENVIRONMENT)" -var="aws_region=$(AWS_REGION)" -auto-approve

configure-kubectl: ## Configure kubectl for EKS
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)

install-alb: ## Install AWS Load Balancer Controller
	./scripts/install-alb-controller.sh $(CLUSTER_NAME) $(AWS_REGION)

setup-irsa: ## Setup IRSA for application
	./scripts/setup-irsa.sh $(CLUSTER_NAME) $(AWS_REGION)

build: ## Build Docker image
	cd app && docker build -t eks-assignment-app:latest .

push: ## Push Docker image to ECR
	@echo "Pushing to ECR..."
	@ECR_REPO=$$(cd terraform && terraform output -raw ecr_repository_url) && \
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $${ECR_REPO%%/*} && \
	docker tag eks-assignment-app:latest $$ECR_REPO:latest && \
	docker push $$ECR_REPO:latest

deploy-app: ## Deploy application to Kubernetes
	kubectl apply -f app/k8s/

install-monitoring: ## Install monitoring stack
	./scripts/install-monitoring.sh $(CLUSTER_NAME) $(AWS_REGION)

check-pods: ## Check pod status
	kubectl get pods -n eks-assignment

check-services: ## Check service status
	kubectl get svc -n eks-assignment

check-ingress: ## Check ingress status
	kubectl get ingress -n eks-assignment

logs: ## Show application logs
	kubectl logs -f deployment/eks-assignment-app -n eks-assignment

clean: ## Clean local files
	find . -name "*.bak" -delete
	find . -name ".DS_Store" -delete

full-deploy: init apply configure-kubectl install-alb setup-irsa build push deploy-app install-monitoring ## Full deployment (all steps)

status: ## Show cluster status
	@echo "=== Nodes ==="
	kubectl get nodes
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n eks-assignment
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n eks-assignment
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress -n eks-assignment
