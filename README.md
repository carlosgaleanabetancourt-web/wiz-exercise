# ☁️ Wiz Technical Exercise

> **Cloud-native security architecture on AWS**
>
> A production-style Kubernetes platform built with Terraform, AWS EKS and DevSecOps security controls.

<p align="center">

**AWS** · **EKS** · **Terraform** · **Kubernetes** · **Go** · **WAFv2** · **Trivy** · **GitHub Actions**

</p>

<p align="center">

[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform\&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-232F3E?logo=amazon-aws\&logoColor=white)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?logo=kubernetes\&logoColor=white)](https://kubernetes.io/)
[![Go](https://img.shields.io/badge/Go-Gin-00ADD8?logo=go\&logoColor=white)](https://go.dev/)
[![Security](https://img.shields.io/badge/Security-DevSecOps-red)](#-security-architecture)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions\&logoColor=white)](#-cicd-pipelines)

</p>

---

## 🎯 Overview

This repository implements a **cloud-native security exercise** on AWS, combining infrastructure as code, Kubernetes security, application security, vulnerability management, observability and CI/CD.

The platform consists of:

* A **Go/Gin todo application (Tasky)** running on Amazon EKS
* **MongoDB 3.6.8** hosted on an EC2 instance
* An **Application Load Balancer** protected by AWS WAFv2
* Infrastructure provisioned entirely with **Terraform**
* Kubernetes workloads protected with **NetworkPolicies, Pod Security Standards and hardened containers**
* Security scanning integrated into **GitHub Actions**
* Detection and monitoring through **AWS Config, GuardDuty, Inspector, CloudWatch and VPC Flow Logs**
* Automated daily backups and **AWS cost-optimization schedules**

> ⚠️ **Security exercise notice**
>
> Several vulnerabilities are intentionally present because they are part of the exercise specification. They are documented separately and should **not** be interpreted as recommended production configurations.

---

## 🏗️ Architecture

<img width="1510" height="880" alt="AWS cloud-native security architecture" src="https://github.com/user-attachments/assets/2d68c8e9-0e93-42b6-88fe-975c8197da64" />

### Request flow

```text
                         INTERNET
                            │
                            ▼
                    ┌───────────────┐
                    │    AWS WAF    │
                    │ OWASP + Rate  │
                    │    Limiting   │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │      ALB      │
                    │    Ingress    │
                    └───────┬───────┘
                            │
                            ▼
              ┌────────────────────────────┐
              │        AWS EKS             │
              │                            │
              │   ┌───────────────────┐    │
              │   │   Tasky / Go      │    │
              │   │   2 replicas      │    │
              │   │   non-root UID1000│    │
              │   │   NetworkPolicy   │    │
              │   └────────┬──────────┘    │
              └────────────┼───────────────┘
                           │
                           │ MongoDB :27017
                           ▼
                   ┌─────────────────┐
                   │   MongoDB EC2   │
                   │   Ubuntu 20.04  │
                   │   MongoDB 3.6.8 │
                   └────────┬────────┘
                            │
                      mongodump
                            │
                            ▼
                     ┌─────────────┐
                     │ S3 Backups  │
                     └─────────────┘
```

### Network layout

```text
┌──────────────────────────────────────────────────────────────┐
│                    AWS VPC 10.0.0.0/16                       │
│                                                              │
│   Public Subnets                 Private Subnets             │
│                                                              │
│   ┌──────────────────┐           ┌────────────────────────┐  │
│   │   MongoDB EC2    │           │       EKS Cluster      │  │
│   │                  │           │                        │  │
│   │ Ubuntu 20.04     │◄──────────│ Tasky / Go             │  │
│   │ MongoDB 3.6.8    │           │ 2 replicas             │  │
│   │ SSH :22          │           │ non-root               │  │
│   └──────────────────┘           │ NetworkPolicy          │  │
│                                  │ Pod Security Standards │  │
│                                  └────────────────────────┘  │
│                                                              │
│   ┌──────────────────┐                                       │
│   │    S3 Backup     │                                       │
│   │    Bucket        │                                       │
│   └──────────────────┘                                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 🚀 What I Built

| Area                        | Implementation                            |
| --------------------------- | ----------------------------------------  |
| ☁️ Cloud                    | AWS                                      |
| 🏗️ Infrastructure           | Terraform                                |
| ☸️ Containers               | Kubernetes / Amazon EKS                  |
| 🔐 Application Security     | AWS WAFv2 + Kubernetes security controls |
| 🛡️ IaC Security             | Checkov + Trivy                          |
| 🐳 Container Security       | Trivy + Amazon Inspector                 |
| 🔑 CI/CD Authentication     | GitHub OIDC                              |
| 📊 Observability            | CloudWatch + Container Insights          |
| 🚨 Threat Detection         | GuardDuty                                |
| 🔎 Configuration Monitoring | AWS Config                               |
| 💾 Backups                  | MongoDB → S3                             |
| 💰 Cost Optimization        | EventBridge Scheduler                    |

---

# 🔐 Security Architecture

The platform uses **defense in depth**, combining preventative and detective controls across the cloud, Kubernetes, container, infrastructure and CI/CD layers.

```text
                         ┌───────────────────┐
                         │      INTERNET     │
                         └─────────┬─────────┘
                                   │
                         ┌─────────▼─────────┐
                         │       WAFv2       │
                         │ OWASP + Rate Limit│
                         └─────────┬─────────┘
                                   │
                         ┌─────────▼─────────┐
                         │        ALB        │
                         └─────────┬─────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │            EKS              │
                    │                             │
                    │  NetworkPolicy              │
                    │  Pod Security Standards     │
                    │  RBAC                       │
                    │  Non-root containers        │
                    │  No privilege escalation    │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │         AWS SERVICES        │
                    │                             │
                    │ Config · GuardDuty          │
                    │ Inspector · CloudWatch      │
                    │ VPC Flow Logs · ECR         │
                    └─────────────────────────────┘
```

## 🛡️ Preventative Controls

### AWS WAFv2

The ALB is protected with AWS managed rule groups:

* `AWSManagedRulesCommonRuleSet`
* `AWSManagedRulesKnownBadInputsRuleSet`
* `AWSManagedRulesSQLiRuleSet`
* IP-based rate limiting: **2,000 requests / 5 minutes**
* WAF logging to CloudWatch Logs
* BLOCK and COUNT actions captured for analysis

### Kubernetes Network Security

Network traffic follows a **default-deny** model.

Allowed traffic is explicitly defined for:

* Application ingress on port `8080`
* MongoDB traffic on port `27017`
* DNS resolution
* HTTPS egress

### Pod Security

The application namespace uses Pod Security Admission labels.

Containers are hardened with:

* Non-root execution — UID `1000`
* All Linux capabilities dropped
* Privilege escalation disabled
* Explicit security contexts
* Restricted workload configuration

### CI/CD Security

Security checks run automatically through GitHub Actions:

* **Trivy** container vulnerability scanning
* **Trivy** filesystem scanning
* **Trivy** secret scanning
* **Checkov** Terraform security scanning
* Branch protection
* Pull-request based workflow
* CI checks required before merge

### Identity & Encryption

* GitHub Actions uses **OIDC federation**
* No long-lived AWS credentials stored in GitHub
* EKS secrets encrypted at rest
* EBS default encryption enabled
* SNS topic encryption enabled
* AWS Secrets Manager stores MongoDB credentials and JWT signing key

---

# 🔎 Detective Controls

Security visibility is provided through multiple AWS services.

| Control                  | Purpose                                     |
| ------------------------ | ------------------------------------------- |
| **AWS Config**           | Detect infrastructure misconfigurations     |
| **Amazon Inspector**     | Continuous ECR image vulnerability scanning |
| **GuardDuty**            | Threat detection                            |
| **EKS Audit Logs**       | Kubernetes API activity                     |
| **VPC Flow Logs**        | Network traffic visibility                  |
| **CloudWatch Alarms**    | Infrastructure health                       |
| **WAF Logs**             | Web attack visibility                       |
| **CloudWatch Dashboard** | Centralized security monitoring             |

### AWS Config

Five managed rules are enabled:

* `restricted-ssh`
* `s3-public-read-prohibited`
* `s3-bucket-server-side-encryption-enabled`
* `s3-bucket-versioning-enabled`
* `restricted-common-ports`

### Amazon Inspector

ECR images are continuously scanned for newly discovered vulnerabilities after they are pushed.

This means the repository is not limited to detecting CVEs that existed at image-build time.

### GuardDuty

Enabled data sources/features include:

* CloudTrail
* DNS logs
* VPC Flow Logs
* S3 data events
* EKS audit logs
* EBS malware protection
* RDS login activity

### EKS Audit Logging

All five EKS log types are enabled:

```text
api
audit
authenticator
controllerManager
scheduler
```

### CloudWatch

The security dashboard contains **17 widgets**, covering:

* WAF metrics
* WAF logs
* ALB performance
* Pod health
* Infrastructure status
* Security events

Dashboard:

```text
wiz-exercise-security
```

---

# ⚠️ Intentional Security Weaknesses

The following weaknesses are **intentional** and required by the exercise specification.

| Severity | Weakness         | Implementation                                                  |
| -------- | ---------------- | --------------------------------------------------------------- |
| 🔴       | Open SSH         | `0.0.0.0/0 → TCP/22`                                            |
| 🔴       | Excessive IAM    | EC2 role includes `ec2:RunInstances` and `ec2:Describe*` on `*` |
| 🔴       | Public S3        | Block Public Access disabled; public read/list access           |
| 🔴       | Excessive RBAC   | Tasky ServiceAccount bound to `cluster-admin`                   |
| 🟠       | Outdated MongoDB | MongoDB `3.6.8` — EOL April 2021                                |
| 🟠       | Outdated OS      | Ubuntu `20.04` — standard support ended April 2025              |

### Why are these vulnerabilities present?

The purpose of the exercise is to demonstrate the ability to:

1. Identify security weaknesses
2. Understand their impact
3. Implement detective controls
4. Monitor the environment
5. Distinguish intentional vulnerabilities from secure design controls

> **These configurations should be remediated before using this architecture in production.**

---

# 💰 Cost Optimization

The environment includes automated schedules to minimize AWS costs when the platform is not being used.

### Daily schedule — `America/Mexico_City`

| Time         | Action               |
| ------------ | -------------------- |
| **08:00**    | Start MongoDB EC2    |
| **08:00**    | Scale EKS nodes to 2 |
| **09:00 PM** | Run `mongodump` → S3 |
| **10:00 PM** | Stop MongoDB EC2     |
| **10:00 PM** | Scale EKS nodes to 0 |

Estimated savings:

> **~$2/day · ~20% infrastructure reduction**

EBS data persists across EC2 stop/start cycles.

MongoDB, the backup cron job and the backup script automatically recover after reboot.

---

# 🔄 CI/CD Pipelines

Three GitHub Actions workflows implement the delivery and security pipeline.

## Infrastructure Pipeline

```text
Push / Pull Request
        │
        ▼
Terraform Format
        │
        ▼
Terraform Validate
        │
        ▼
Trivy IaC Scan
        │
        ▼
Terraform Plan
        │
        ▼
     main?
      /   \
    no     yes
          │
          ▼
     Terraform Apply
```

Workflow:

```text
.github/workflows/terraform.yml
```

## Application Pipeline

```text
Push / Pull Request
        │
        ▼
   Docker Build
        │
        ▼
 Trivy Container Scan
        │
        ▼
      ECR Push
        │
        ▼
    EKS Deploy
        │
        ├── Deployment
        ├── Service
        ├── NetworkPolicy
        └── Ingress + WAF
```

Workflow:

```text
.github/workflows/build-and-deploy.yaml
```

## Security Pipeline

```text
Pull Request / Push
        │
        ├───────────────┐
        ▼               ▼
    Checkov           Trivy
    IaC Scan       Filesystem Scan
                        │
                        ▼
                  Secret Scanning
```

Workflow:

```text
.github/workflows/security.yaml
```

### Authentication

All AWS interactions from GitHub Actions use:

```text
GitHub Actions
      │
      ▼
   OIDC Token
      │
      ▼
AWS IAM Role
```

No static AWS access keys are stored in GitHub.

---

# 📁 Repository Structure

```text
.github/
└── workflows/
    ├── terraform.yml
    │   └── Terraform format, validation, Trivy, plan & apply
    │
    ├── build-and-deploy.yaml
    │   └── Docker build, Trivy, ECR & EKS deployment
    │
    └── security.yaml
        └── Checkov, Trivy filesystem & secret scanning

app/
├── Dockerfile
├── main.go
└── wizexercise.txt

kubernetes/
├── namespace.yaml
├── deployment.yaml
├── service.yaml
├── ingress.yaml
├── network-policy.yaml
└── rbac.yaml

terraform/
├── eks.tf
├── mongodb.tf
├── networking.tf
├── waf.tf
├── dashboard.tf
├── scheduler.tf
├── iam.tf
├── security-groups.tf
├── s3.tf
├── config.tf
├── guardduty.tf
├── cloudwatch.tf
├── secrets.tf
├── ecr.tf
├── alb-controller.tf
├── ebs-encryption.tf
├── cloudwatch-observability.tf
├── providers.tf
├── variables.tf
└── outputs.tf

scripts/
├── create-k8s-secrets.sh
├── deploy-app.sh
└── mongodb-backup.sh
```

---

# 🧰 Technology Stack

### Cloud

* AWS VPC
* Amazon EKS
* EC2
* S3
* ECR
* ALB
* AWS WAFv2
* IAM
* Secrets Manager
* GuardDuty
* AWS Config
* Amazon Inspector
* CloudWatch
* EventBridge Scheduler
* SNS

### Infrastructure

* Terraform
* Kubernetes
* Helm
* AWS Load Balancer Controller

### Application

* Go
* Gin
* MongoDB
* JWT authentication
* Docker

### Security

* Trivy
* Checkov
* AWS WAF
* NetworkPolicies
* Pod Security Standards
* RBAC
* OIDC
* KMS encryption

---

# 🧠 Engineering Decisions

## Why EKS?

EKS provides a managed Kubernetes control plane while allowing the application workloads to use Kubernetes-native security controls such as NetworkPolicies, RBAC and Pod Security Admission.

## Why Terraform?

Terraform provides reproducible infrastructure and makes the security configuration version-controlled and reviewable.

## Why GitHub OIDC?

OIDC removes the need for long-lived AWS access keys in GitHub Actions.

```text
Traditional:

GitHub → AWS Access Key → AWS

This project:

GitHub → OIDC → IAM Role → AWS
```

## Why WAF?

WAF introduces an additional application-layer security boundary before traffic reaches the Kubernetes workload.

## Why NetworkPolicies?

The default-deny model reduces lateral movement by requiring communication paths to be explicitly authorized.

## Why automated shutdown?

The environment is an exercise rather than a 24/7 production service. Automatically stopping compute resources reduces unnecessary AWS spend while preserving persistent data.

---

# 📋 Prerequisites

* AWS account with appropriate permissions
* Terraform `>= 1.0`
* AWS CLI
* kubectl
* GitHub repository with AWS OIDC provider configured
* GitHub Secrets:

  * `AWS_ROLE_ARN`
  * `TERRAFORM_TFVARS`

---

# 🚀 Deployment

## Infrastructure

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

Infrastructure deployment is normally handled by the Terraform GitHub Actions pipeline.

## Application

The application is automatically deployed when changes are pushed to:

```text
app/**
kubernetes/**
```

For manual deployment:

```bash
aws eks update-kubeconfig \
  --name wiz-exercise-eks \
  --region us-east-1

kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/rbac.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/network-policy.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/deployment.yaml
```

---

# ✅ Validation

### Kubernetes

```bash
kubectl get pods -n wiz-exercise
```

### Application endpoint

```bash
kubectl get ingress -n wiz-exercise
```

### Exercise validation file

```bash
kubectl exec -it \
  deploy/tasky \
  -n wiz-exercise \
  -- cat /app/wizexercise.txt
```

### MongoDB connectivity

```bash
kubectl logs deploy/tasky -n wiz-exercise
```

### NetworkPolicies

```bash
kubectl get networkpolicies \
  -n wiz-exercise
```

### Pod Security Admission

```bash
kubectl get ns wiz-exercise \
  --show-labels
```

### WAF attachment

```bash
kubectl describe ingress tasky \
  -n wiz-exercise | grep wafv2
```

### CloudWatch

Open:

```text
AWS Console
    ↓
CloudWatch
    ↓
Dashboards
    ↓
wiz-exercise-security
```

---

# 📚 Lessons Learned

This exercise demonstrates how security controls can be layered across the entire cloud-native stack:

```text
Application
     ↓
Container
     ↓
Kubernetes
     ↓
Network
     ↓
AWS Infrastructure
     ↓
CI/CD
     ↓
Monitoring & Detection
```

The key takeaway is that **no single security control is sufficient**. Preventative controls, continuous scanning, identity security, network isolation and detective capabilities must work together to reduce risk.

---

# 📝 Final Notes

This repository was built as a **cloud security / DevSecOps technical exercise**.

The architecture intentionally combines secure engineering practices with specific vulnerabilities required by the exercise. The vulnerable components are explicitly documented so they can be identified, monitored and eventually remediated.

**Production recommendation:** remove all intentional weaknesses before deploying a similar architecture to a real environment.

---

<p align="center">

### ☁️ Built with AWS · Kubernetes · Terraform · Go · DevSecOps

</p>
