#!/bin/bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-wiz-exercise}"
NAMESPACE="${K8S_NAMESPACE:-wiz-exercise}"

echo "Fetching MongoDB credentials from Secrets Manager..."
MONGO_CREDS=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "${PROJECT}/mongodb-credentials" \
  --query SecretString \
  --output text)

MONGODB_URI=$(echo "$MONGO_CREDS" | jq -r '.uri')

echo "Fetching JWT secret key from Secrets Manager..."
JWT_SECRET=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "${PROJECT}/jwt-secret-key" \
  --query SecretString \
  --output text)

echo "Creating Kubernetes namespace if it does not exist..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Kubernetes secret from Secrets Manager values..."
kubectl create secret generic tasky-secret \
  -n "$NAMESPACE" \
  --from-literal=MONGODB_URI="$MONGODB_URI" \
  --from-literal=SECRET_KEY="$JWT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Kubernetes secret 'tasky-secret' created in namespace '$NAMESPACE'."
kubectl get secret tasky-secret -n "$NAMESPACE"
