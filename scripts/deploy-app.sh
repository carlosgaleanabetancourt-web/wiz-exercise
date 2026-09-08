#!/bin/bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-wiz-exercise}"
NAMESPACE="${K8S_NAMESPACE:-wiz-exercise}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT}:${IMAGE_TAG}"

echo "Resolving deployment values..."
echo "  Account:   ${ACCOUNT_ID}"
echo "  ECR Image: ${ECR_IMAGE}"
echo "  Namespace: ${NAMESPACE}"

echo "Applying namespace..."
kubectl apply -f kubernetes/namespace.yaml

echo "Applying RBAC (ServiceAccount + cluster-admin binding)..."
kubectl apply -f kubernetes/rbac.yaml

echo "Syncing secrets from Secrets Manager..."
./scripts/create-k8s-secrets.sh

echo "Applying deployment (substituting ECR_IMAGE)..."
export ECR_IMAGE
envsubst '${ECR_IMAGE}' < kubernetes/deployment.yaml | kubectl apply -f -

echo "Applying service..."
kubectl apply -f kubernetes/service.yaml

echo "Applying ingress..."
kubectl apply -f kubernetes/ingress.yaml

echo "Waiting for rollout..."
kubectl rollout status deployment/tasky -n "$NAMESPACE" --timeout=300s

echo "Deployment complete."
kubectl get pods -n "$NAMESPACE" -o wide
