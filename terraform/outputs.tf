output "vpc_id" {
  value = module.vpc.vpc_id
}

output "mongodb_public_ip" {
  value = aws_instance.mongodb.public_ip
}

output "mongodb_private_ip" {
  value = aws_instance.mongodb.private_ip
}

output "backup_bucket" {
  value = aws_s3_bucket.backup.bucket
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "mongodb_credentials_secret_arn" {
  value = aws_secretsmanager_secret.mongodb_credentials.arn
}

output "jwt_secret_key_secret_arn" {
  value = aws_secretsmanager_secret.jwt_secret_key.arn
}

output "mongodb_instance_profile" {
  value = aws_iam_instance_profile.mongodb.name
}

output "github_actions_role_arn" {
  description = "AWS_ROLE_ARN for GitHub Actions"
  value = aws_iam_role.github_actions.arn
}

output "backup_access_logs_bucket" {
  description = "S3 bucket storing access logs for the backup bucket"
  value = aws_s3_bucket.backup_access_logs.bucket
}

output "sns_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  value = aws_sns_topic.alarms.arn
}

output "config_bucket" {
  description = "S3 bucket storing AWS Config snapshots"
  value = aws_s3_bucket.config.bucket
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application image"
  value = aws_ecr_repository.app.repository_url
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value = aws_guardduty_detector.main.id
}
