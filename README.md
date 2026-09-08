# Wiz Exercise

Cloud-native two-tier web application.

The project provisions a containerized web application on Kubernetes with a MongoDB backend running on a Linux VM, cloud object-storage backups, CI/CD pipelines, infrastructure and container security scanning, and cloud-native security monitoring.

The environment intentionally includes several security weaknesses required by the exercise, such as outdated components, exposed SSH, permissive access controls, and public object storage. These configurations are implemented strictly for the isolated technical exercise and are documented with their security implications and recommended mitigations.

## Key Technologies

* AWS / Cloud Infrastructure
* Kubernetes / Amazon EKS
* Terraform
* Docker
* MongoDB
* Amazon S3
* Amazon ECR
* GitHub Actions
* CloudTrail / AWS Config
* Infrastructure & Container Security Scanning

## Objectives

* Deploy a functional two-tier cloud-native application
* Demonstrate Kubernetes administration and RBAC
* Implement Infrastructure as Code with Terraform
* Build automated application and infrastructure CI/CD pipelines
* Demonstrate intentional security weaknesses and their impact
* Apply preventative and detective cloud security controls
* Validate application-to-database connectivity and data persistence
* Demonstrate security considerations throughout the development lifecycle
