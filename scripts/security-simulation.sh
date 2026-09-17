#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
PROJECT="wiz-exercise"
QUICK=false

[[ "${1:-}" == "--quick" ]] && QUICK=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

header() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${BOLD}  $1${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

vuln()    { echo -e "  ${RED}[VULNERABILITY]${NC} $1"; }
probe()   { echo -e "  ${YELLOW}[PROBE]${NC} $1"; }
detect()  { echo -e "  ${GREEN}[DETECTED BY]${NC} $1"; }
info()    { echo -e "  ${CYAN}[INFO]${NC} $1"; }

pause() {
  if [[ "$QUICK" == false ]]; then
    echo ""
    read -rp "  Press Enter to continue to next scenario..."
  fi
  echo ""
}

# ─────────────────────────────────────────────────────────────
header "SCENARIO 1: Public S3 Bucket — Data Exposure"
# ─────────────────────────────────────────────────────────────

vuln "Backup S3 bucket allows public read and listing"

BACKUP_BUCKET=$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'${PROJECT}-backup-')&&!contains(Name,'logs')].Name | [0]" --output text --region "$REGION")
info "Discovered bucket: $BACKUP_BUCKET"

probe "Listing bucket contents anonymously (no AWS credentials)..."
ANON_RESULT=$(curl -s "https://${BACKUP_BUCKET}.s3.amazonaws.com" 2>/dev/null | head -c 500 || true)
if echo "$ANON_RESULT" | grep -q "ListBucketResult"; then
  vuln "Anonymous listing SUCCEEDED — anyone on the internet can see backup files"
else
  info "Anonymous listing returned: $(echo "$ANON_RESULT" | head -c 100)"
fi

probe "Checking AWS Config compliance..."
CONFIG_STATUS=$(aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "${PROJECT}-s3-public-read-prohibited" \
  --compliance-types NON_COMPLIANT \
  --query "EvaluationResults[?EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId=='${BACKUP_BUCKET}'].ComplianceType | [0]" \
  --output text --region "$REGION" 2>/dev/null || echo "UNKNOWN")
detect "AWS Config rule 's3-public-read-prohibited' → ${CONFIG_STATUS}"

pause

# ─────────────────────────────────────────────────────────────
header "SCENARIO 2: SSH Open to the World"
# ─────────────────────────────────────────────────────────────

vuln "MongoDB security group allows SSH (port 22) from 0.0.0.0/0"

probe "Querying security group rules..."
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${PROJECT}-mongodb" \
  --query "SecurityGroups[0].GroupId" --output text --region "$REGION")

aws ec2 describe-security-groups --group-ids "$SG_ID" --region "$REGION" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`]" --output json | \
  jq -r '.[] | "    Port: \(.FromPort) | Protocol: \(.IpProtocol) | Source: \(.IpRanges[].CidrIp)"'

probe "Checking AWS Config compliance..."
SSH_STATUS=$(aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "${PROJECT}-restricted-ssh" \
  --compliance-types NON_COMPLIANT \
  --query "EvaluationResults[?EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId=='${SG_ID}'].ComplianceType | [0]" \
  --output text --region "$REGION" 2>/dev/null || echo "UNKNOWN")
detect "AWS Config rule 'restricted-ssh' → ${SSH_STATUS}"

SG_PORTS_STATUS=$(aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "${PROJECT}-sg-restricted-ports" \
  --compliance-types NON_COMPLIANT \
  --query "EvaluationResults[?EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId=='${SG_ID}'].ComplianceType | [0]" \
  --output text --region "$REGION" 2>/dev/null || echo "UNKNOWN")
detect "AWS Config rule 'sg-restricted-ports' → ${SG_PORTS_STATUS}"

pause

# ─────────────────────────────────────────────────────────────
header "SCENARIO 3: Over-Privileged IAM — EC2 RunInstances"
# ─────────────────────────────────────────────────────────────

vuln "MongoDB instance role can launch arbitrary EC2 instances (ec2:RunInstances on *)"

probe "Inspecting MongoDB instance role policies..."
ROLE_NAME="${PROJECT}-mongodb"
POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query "PolicyNames" --output json --region "$REGION")
info "Attached inline policies: $POLICIES"

probe "Checking ec2-access policy..."
EC2_POLICY=$(aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "${PROJECT}-mongodb-ec2-access" --region "$REGION" --output json 2>/dev/null || echo "{}")
if echo "$EC2_POLICY" | jq -e '.PolicyDocument.Statement[] | select(.Action[] == "ec2:RunInstances")' > /dev/null 2>&1; then
  RESOURCE=$(echo "$EC2_POLICY" | jq -r '.PolicyDocument.Statement[] | select(.Action[] == "ec2:RunInstances") | .Resource')
  vuln "ec2:RunInstances granted on Resource: $RESOURCE"
  info "This means the MongoDB VM could spin up any EC2 instance in the account"
fi

detect "CloudTrail — any API call from this role is logged under the trail"
detect "GuardDuty — anomalous EC2 launches would trigger UnauthorizedAccess findings"

pause

# ─────────────────────────────────────────────────────────────
header "SCENARIO 4: Kubernetes Cluster-Admin on Application"
# ─────────────────────────────────────────────────────────────

vuln "Application service account 'tasky' has cluster-admin privileges"

probe "Checking what the tasky service account can do..."
echo ""
echo -e "  ${YELLOW}kubectl auth can-i --list --as=system:serviceaccount:wiz-exercise:tasky${NC}"
echo ""
kubectl auth can-i --list --as=system:serviceaccount:wiz-exercise:tasky 2>/dev/null | head -5
echo "  ..."
info "Full cluster-admin: can do ANYTHING in any namespace"

probe "Showing the ClusterRoleBinding..."
BINDING=$(kubectl get clusterrolebinding tasky-cluster-admin -o jsonpath='{.roleRef.name}' 2>/dev/null || echo "not found")
info "tasky SA → ClusterRole: ${BINDING}"

detect "Kubernetes audit logs (CloudWatch /aws/eks/${PROJECT}-eks/cluster)"
detect "GuardDuty EKS audit log monitoring"

pause

# ─────────────────────────────────────────────────────────────
header "SCENARIO 5: GuardDuty — Threat Detection"
# ─────────────────────────────────────────────────────────────

info "GuardDuty continuously monitors for threats across the account"

probe "Checking GuardDuty detector status..."
DETECTOR_ID=$(aws guardduty list-detectors --query "DetectorIds[0]" --output text --region "$REGION")
DETECTOR_STATUS=$(aws guardduty get-detector --detector-id "$DETECTOR_ID" --query "Status" --output text --region "$REGION")
info "Detector: $DETECTOR_ID — Status: $DETECTOR_STATUS"

probe "Checking enabled data sources..."
aws guardduty get-detector --detector-id "$DETECTOR_ID" --region "$REGION" \
  --query "DataSources.{S3Logs:S3Logs.Status,K8sAuditLogs:Kubernetes.AuditLogs.Status}" --output json | \
  jq -r 'to_entries[] | "    \(.key): \(.value)"'

probe "Checking for active findings..."
FINDINGS=$(aws guardduty list-findings --detector-id "$DETECTOR_ID" --region "$REGION" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --query "FindingIds" --output json 2>/dev/null || echo "[]")

FINDING_COUNT=$(echo "$FINDINGS" | jq 'length')
if [[ "$FINDING_COUNT" -gt 0 ]]; then
  vuln "$FINDING_COUNT active GuardDuty finding(s) detected!"
  aws guardduty get-findings --detector-id "$DETECTOR_ID" --finding-ids $(echo "$FINDINGS" | jq -r '.[:3][]') \
    --region "$REGION" --query "Findings[].{Type:Type,Severity:Severity,Title:Title}" --output table 2>/dev/null || true
else
  info "No active findings — environment is currently clean"
  info "GuardDuty would alert on: unauthorized API calls, crypto mining, DNS exfiltration, etc."
fi

detect "GuardDuty with S3 + Kubernetes audit log monitoring"

# ─────────────────────────────────────────────────────────────
header "SUMMARY"
# ─────────────────────────────────────────────────────────────

echo -e "  ${BOLD}Intentional Vulnerabilities${NC}              ${BOLD}Detective Controls${NC}"
echo -e "  ─────────────────────────────────────   ──────────────────────────"
echo -e "  ${RED}1. Public S3 bucket${NC}                      ${GREEN}AWS Config + CloudTrail${NC}"
echo -e "  ${RED}2. SSH open to 0.0.0.0/0${NC}                 ${GREEN}AWS Config (2 rules)${NC}"
echo -e "  ${RED}3. EC2 RunInstances on MongoDB role${NC}      ${GREEN}CloudTrail + GuardDuty${NC}"
echo -e "  ${RED}4. cluster-admin on app SA${NC}               ${GREEN}K8s Audit Logs + GuardDuty${NC}"
echo -e "  ${RED}5. Threats / anomalous behavior${NC}          ${GREEN}GuardDuty (S3 + K8s)${NC}"
echo ""
echo -e "  ${BOLD}Preventative Controls in Place:${NC}"
echo -e "    • WAF with rate limiting, SQLi, and common attack protection"
echo -e "    • CSP headers blocking XSS and injection"
echo -e "    • Network policies restricting pod-to-pod traffic"
echo -e "    • VPC endpoints keeping S3/Secrets Manager traffic off the internet"
echo -e "    • EBS and S3 encryption at rest"
echo -e "    • Trivy + Checkov + secret scanning in CI/CD"
echo ""
