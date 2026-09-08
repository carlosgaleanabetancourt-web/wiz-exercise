variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "wiz-exercise"
}

variable "candidate_name" {
  type    = string
  default = "Carlos Alberto Galeana Betancourt"
}

variable "ssh_public_key" {
  type = string
}

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the EKS public API"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in owner/repo format for OIDC trust"
}

variable "github_oidc_subject" {
  type        = string
  description = "OIDC subject claim prefix from GitHub (Settings > Security > Code security > OIDC customization)"
}

variable "alarm_email" {
  type        = string
  description = "Email for CloudWatch alarm notifications"
  default     = ""
}
