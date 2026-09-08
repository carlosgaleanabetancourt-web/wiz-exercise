resource "aws_kms_key" "sns" {
  description = "KMS key for SNS topic encryption"
  deletion_window_in_days = 7
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"
  kms_master_key_id = aws_kms_key.sns.id
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol = "email"
  endpoint = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "mongodb_cpu" {
  alarm_name = "${var.project_name}-mongodb-cpu-high"
  alarm_description = "MongoDB EC2 CPU utilization above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 300
  statistic = "Average"
  threshold = 80
  treat_missing_data = "missing"

  dimensions = {
    InstanceId = aws_instance.mongodb.id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "mongodb_status_check" {
  alarm_name = "${var.project_name}-mongodb-status-check"
  alarm_description = "MongoDB EC2 instance or system status check failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  metric_name = "StatusCheckFailed"
  namespace = "AWS/EC2"
  period = 300
  statistic = "Maximum"
  threshold = 0
  treat_missing_data = "breaching"

  dimensions = {
    InstanceId = aws_instance.mongodb.id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "eks_node_cpu" {
  alarm_name = "${var.project_name}-eks-node-cpu-high"
  alarm_description = "EKS node group average CPU above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 3
  metric_name = "node_cpu_utilization"
  namespace = "ContainerInsights"
  period = 300
  statistic = "Average"
  threshold = 80
  treat_missing_data = "missing"

  dimensions = {
    ClusterName = module.eks.cluster_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "eks_node_memory" {
  alarm_name = "${var.project_name}-eks-node-memory-high"
  alarm_description = "EKS node group average memory above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 3
  metric_name = "node_memory_utilization"
  namespace = "ContainerInsights"
  period = 300
  statistic = "Average"
  threshold = 80
  treat_missing_data = "missing"

  dimensions = {
    ClusterName = module.eks.cluster_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "eks_node_count" {
  alarm_name = "${var.project_name}-eks-node-count-low"
  alarm_description = "EKS cluster has fewer than 2 nodes"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  metric_name = "cluster_node_count"
  namespace = "ContainerInsights"
  period = 300
  statistic = "Average"
  threshold = 2
  treat_missing_data = "breaching"

  dimensions = {
    ClusterName = module.eks.cluster_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}
