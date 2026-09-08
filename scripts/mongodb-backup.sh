#!/bin/bash
set -euo pipefail

DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/opt/mongodb-backups/${DATE}"
REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-wiz-exercise}"

BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, '${PROJECT}-backup-') && !contains(Name, 'logs')].Name | [0]" \
  --output text)

if [ "$BUCKET" = "None" ] || [ -z "$BUCKET" ]; then
  echo "ERROR: backup bucket not found" >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

CREDS=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "${PROJECT}/mongodb-credentials" \
  --query SecretString \
  --output text)

MONGO_USER=$(echo "$CREDS" | jq -r '.username')
MONGO_PASS=$(echo "$CREDS" | jq -r '.password')

mongodump \
  --host localhost \
  --authenticationDatabase admin \
  --username "$MONGO_USER" \
  --password "$MONGO_PASS" \
  --out "${BACKUP_DIR}"

aws s3 cp \
  "${BACKUP_DIR}" \
  "s3://${BUCKET}/${DATE}/" \
  --recursive

find /opt/mongodb-backups -type d -mtime +7 -exec rm -rf {} +
