data "aws_caller_identity" "current" {}

resource "aws_iam_role" "mongodb" {
  name = "${var.project_name}-mongodb"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mongodb"
  }
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "${var.project_name}-mongodb"
  role = aws_iam_role.mongodb.name
}

resource "aws_iam_role_policy" "mongodb_s3_backup" {
  name = "${var.project_name}-mongodb-s3-backup"
  role = aws_iam_role.mongodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBackupUpload"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.backup.arn}/*"
      },
      {
        Sid    = "AllowBackupList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.backup.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "mongodb_secrets_manager" {
  name = "${var.project_name}-mongodb-secrets-manager"
  role = aws_iam_role.mongodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGetCredentials"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.mongodb_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "mongodb_cloudwatch_logs" {
  name = "${var.project_name}-mongodb-cloudwatch-logs"
  role = aws_iam_role.mongodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/wiz-exercise/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "mongodb_ec2_access" {
  name = "${var.project_name}-mongodb-ec2-access"
  role = aws_iam_role.mongodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Operations"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "${var.github_oidc_subject}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions"
  }
}

resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "${var.project_name}-github-actions-terraform"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECR"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListTagsForResource",
          "ecr:GetRepositoryPolicy",
          "ecr:GetLifecyclePolicy",
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:PutImageTagMutability",
          "ecr:PutImageScanningConfiguration",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEKS"
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:ImportKeyPair",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateFlowLogs",
          "ec2:DeleteFlowLogs",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:EnableEbsEncryptionByDefault",
          "ec2:GetEbsEncryptionByDefault",
          "ec2:ModifyEbsDefaultKmsKeyId",
          "ec2:ResetEbsDefaultKmsKeyId",
          "ec2:CreateNetworkAclEntry",
          "ec2:DeleteNetworkAclEntry",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifySubnetAttribute"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowIAM"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRolePolicy",
          "iam:GetInstanceProfile",
          "iam:GetOpenIDConnectProvider",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListPolicyVersions",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:TagInstanceProfile",
          "iam:TagOpenIDConnectProvider",
          "iam:PassRole",
          "iam:CreateServiceLinkedRole",
          "iam:ListOpenIDConnectProviders"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketLocation",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetReplicationConfiguration",
          "s3:GetAnalyticsConfiguration",
          "s3:GetInventoryConfiguration",
          "s3:GetMetricsConfiguration",
          "s3:GetIntelligentTieringConfiguration",
          "s3:GetBucketOwnershipControls",
          "s3:GetObjectVersionForReplication"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowKMS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListResourceTags",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:EnableKeyRotation",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:PutKeyPolicy",
          "kms:ListAliases",
          "kms:CreateGrant",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatch"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsLogGroup",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:CreateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSNS"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListTagsForResource",
          "sns:TagResource",
          "sns:UntagResource",
          "sns:GetSubscriptionAttributes"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowConfig"
        Effect = "Allow"
        Action = [
          "config:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowGuardDuty"
        Effect = "Allow"
        Action = [
          "guardduty:CreateDetector",
          "guardduty:DeleteDetector",
          "guardduty:GetDetector",
          "guardduty:UpdateDetector",
          "guardduty:ListDetectors",
          "guardduty:TagResource",
          "guardduty:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowELB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAutoScaling"
        Effect = "Allow"
        Action = [
          "autoscaling:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSSM"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSTS"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchDashboards"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:GetDashboard",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowWAFv2"
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL",
          "wafv2:DeleteWebACL",
          "wafv2:GetWebACL",
          "wafv2:UpdateWebACL",
          "wafv2:ListWebACLs",
          "wafv2:ListTagsForResource",
          "wafv2:TagResource",
          "wafv2:UntagResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:PutLoggingConfiguration",
          "wafv2:GetLoggingConfiguration",
          "wafv2:DeleteLoggingConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowScheduler"
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:ListSchedules",
          "scheduler:TagResource",
          "scheduler:UntagResource",
          "scheduler:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowTerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::wiz-exercise-tfstate-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::wiz-exercise-tfstate-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Sid    = "AllowTerraformLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/wiz-exercise-tflock"
      }
    ]
  })
}
