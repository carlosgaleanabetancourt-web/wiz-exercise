# Wiz Technical Exercise v4

Two-tier cloud-native web application on AWS with intentional security weaknesses, automated infrastructure, and layered security controls.

## Architecture

```
Internet
   │
   ▼
┌──────────┐    ┌─────────────────────────────────────────────┐
│  WAFv2   │    │              AWS VPC (10.0.0.0/16)          │
│ (OWASP + │    │                                             │
│  rate    │    │  Public Subnets          Private Subnets    │
│  limit)  │    │  ┌───────────────┐   ┌───────────────────┐  │
└────┬─────┘    │  │ MongoDB EC2   │   │ EKS Cluster v1.36 │  │
     │          │  │ Ubuntu 20.04  │   │ ┌───────────────┐ │  │
     ▼          │  │ MongoDB 3.6.8 │◄──│ │ Tasky (Go)    │ │  │
┌──────────┐    │  │ SSH :22 open  │   │ │ 2 replicas    │ │  │
│   ALB    │────│  └───────────────┘   │ │ non-root 1000 │ │  │
│ (ingress)│    │                      │ │ NetworkPolicy │ │  │
└──────────┘    │  ┌───────────────┐   │ │ PSS baseline  │ │  │
                │  │ S3 Backup     │   │ └───────────────┘ │  │
                │  │ PUBLIC read   │◄──│ (daily mongodump) │  │
                │  └───────────────┘   └───────────────────┘  │
                └─────────────────────────────────────────────┘
```

**Frontend:** Tasky — a Go/Gin todo application running on EKS, exposed via ALB with WAFv2 protection.

**Backend:** MongoDB 3.6.8 on an Ubuntu 20.04 EC2 instance in a public subnet with daily automated backups to S3.

## Repository Structure

```
.github/workflows/
  terraform.yml            # IaC pipeline: fmt, validate, Trivy scan, plan, apply
  build-and-deploy.yaml    # App pipeline: Docker build, Trivy scan, ECR push, EKS deploy
  security.yaml            # tfsec static analysis on PRs

app/
  Dockerfile               # Multi-stage build, non-root user (UID 1000)
  main.go                  # Tasky Go application
  wizexercise.txt          # Exercise validation file with candidate name

kubernetes/
  namespace.yaml           # Pod Security Admission labels (baseline/restricted)
  deployment.yaml          # 2 replicas, securityContext (drop ALL, no escalation)
  service.yaml             # ClusterIP service
  ingress.yaml             # ALB ingress with WAFv2 annotation
  network-policy.yaml      # Default-deny + explicit allow rules
  rbac.yaml                # ServiceAccount + cluster-admin binding (intentional)

terraform/
  eks.tf                   # EKS cluster, VPC CNI with network policy controller
  mongodb.tf               # EC2 instance, user-data bootstrap
  networking.tf            # VPC, subnets, NAT gateways, flow logs
  waf.tf                   # WAFv2 WebACL (OWASP rules + rate limiting)
  dashboard.tf             # CloudWatch security dashboard (16 widgets)
  scheduler.tf             # EventBridge cost-savings schedules
  iam.tf                   # IAM roles (MongoDB, GitHub Actions, ALB controller, scheduler)
  security-groups.tf       # MongoDB SG (SSH 0.0.0.0/0, MongoDB VPC-only)
  s3.tf                    # Backup bucket (public), access logs, Config delivery
  config.tf                # AWS Config (5 managed rules)
  guardduty.tf             # GuardDuty detector (7 features)
  cloudwatch.tf            # Alarms (5) and SNS topic
  secrets.tf               # Secrets Manager (MongoDB creds, JWT key)
  ecr.tf                   # ECR repository
  alb-controller.tf        # AWS Load Balancer Controller Helm release
  ebs-encryption.tf        # EBS default encryption
  cloudwatch-observability.tf  # Container Insights EKS addon
  providers.tf             # AWS provider, S3 backend
  variables.tf             # Input variables
  outputs.tf               # Terraform outputs

scripts/
  create-k8s-secrets.sh    # Syncs AWS Secrets Manager to K8s secrets
  deploy-app.sh            # Manual deployment helper
  mongodb-backup.sh        # Backup script reference
```

## Intentional Security Weaknesses

These are required by the exercise specification:

| Weakness | Detail |
|----------|--------|
| Open SSH | Security group allows 0.0.0.0/0 on port 22 to the MongoDB VM |
| Overly permissive IAM | MongoDB EC2 role has ec2:RunInstances and ec2:Describe* on `*` |
| Public S3 bucket | Backup bucket has Block Public Access disabled, allows public read and listing |
| cluster-admin RBAC | Tasky ServiceAccount bound to cluster-admin ClusterRole |
| Outdated MongoDB | MongoDB 3.6.8 (EOL April 2021) |
| Outdated OS | Ubuntu 20.04 LTS (standard support ended April 2025) |

## Security Controls

### Preventative

- **WAFv2 on ALB** — AWS managed rule groups: CommonRuleSet, KnownBadInputsRuleSet, SQLiRuleSet, plus IP-based rate limiting (2000 req/5min)
- **K8s Network Policies** — Default-deny-all with explicit allow: ingress on 8080, egress to MongoDB (27017), DNS, and HTTPS
- **Pod Security Standards** — Namespace labels: baseline enforce, restricted warn/audit
- **Container hardening** — Non-root user (UID 1000), all capabilities dropped, privilege escalation disabled
- **Trivy** — Blocks container images with CRITICAL/HIGH CVEs in CI
- **tfsec** — Scans Terraform for misconfigurations on PRs
- **Branch protection** — PRs required, CI must pass before merge
- **KMS encryption** — EKS secrets at rest, EBS default encryption, SNS topic encryption
- **OIDC federation** — GitHub Actions authenticates via OIDC, zero static credentials

### Detective

- **AWS Config** — 5 managed rules: restricted-ssh, s3-public-read-prohibited, s3-bucket-server-side-encryption-enabled, s3-bucket-versioning-enabled, restricted-common-ports
- **GuardDuty** — 7 features: CloudTrail, DNS logs, VPC Flow Logs, S3 data events, EKS audit logs, EBS malware protection, RDS login activity
- **EKS audit logging** — All 5 log types (api, audit, authenticator, controllerManager, scheduler)
- **VPC Flow Logs** — All traffic captured to CloudWatch Logs (30-day retention)
- **CloudWatch Alarms** — MongoDB CPU/status, EKS node CPU/memory/count
- **CloudWatch Dashboard** — `wiz-exercise-security`: WAF metrics, ALB performance, pod health, infrastructure status (16 widgets)

### Cost Optimization

EventBridge Scheduler stops MongoDB EC2 and scales EKS nodes to 0 at 10 PM CST, restarts at 8 AM CST. Saves ~$2/day (~20% reduction) while preserving all data.

## CI/CD Pipelines

| Pipeline | Trigger | Steps |
|----------|---------|-------|
| `terraform.yml` | Push/PR to `terraform/**` | Format check, init, validate, Trivy IaC scan, plan, apply (main only) |
| `build-and-deploy.yaml` | Push/PR to `app/**`, `kubernetes/**` | Docker build, Trivy container scan, ECR push, K8s deploy with network policies and WAF |
| `security.yaml` | PR to `terraform/**` | tfsec static analysis |

All pipelines use GitHub OIDC federation with AWS (no static credentials).

## Prerequisites

- AWS account with appropriate permissions
- Terraform >= 1.0
- kubectl configured for EKS
- GitHub repository with OIDC provider configured
- GitHub Secrets: `AWS_ROLE_ARN`, `TERRAFORM_TFVARS`

## Deployment

Infrastructure is deployed via the Terraform pipeline on push to main:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The application is deployed via the build-and-deploy pipeline on push to main. For manual deployment:

```bash
aws eks update-kubeconfig --name wiz-exercise-eks --region us-east-1
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/rbac.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/network-policy.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/deployment.yaml
```

## Validation

```bash
# Verify pods are running
kubectl get pods -n wiz-exercise

# Check the ALB URL
kubectl get ingress -n wiz-exercise

# Verify wizexercise.txt
kubectl exec -it deploy/tasky -n wiz-exercise -- cat /app/wizexercise.txt

# Verify MongoDB connectivity
kubectl logs deploy/tasky -n wiz-exercise

# Check network policies
kubectl get networkpolicies -n wiz-exercise

# Check Pod Security Admission labels
kubectl get ns wiz-exercise --show-labels

# Verify WAF is attached
kubectl describe ingress tasky -n wiz-exercise | grep wafv2

# View CloudWatch dashboard
# AWS Console -> CloudWatch -> Dashboards -> wiz-exercise-security
```
