resource "aws_iam_role" "scheduler" {
  name = "${var.project_name}-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-scheduler"
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name = "${var.project_name}-scheduler"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2StopStart"
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        Resource = aws_instance.mongodb.arn
      },
      {
        Sid    = "AllowEKSNodeGroupScale"
        Effect = "Allow"
        Action = [
          "eks:UpdateNodegroupConfig",
          "eks:DescribeNodegroup"
        ]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/${module.eks.cluster_name}/*/*"
      }
    ]
  })
}

resource "aws_scheduler_schedule" "stop_mongodb" {
  name       = "${var.project_name}-stop-mongodb"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(10 6 * * ? *)"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      InstanceIds = [aws_instance.mongodb.id]
    })
  }
}

resource "aws_scheduler_schedule" "start_mongodb" {
  name       = "${var.project_name}-start-mongodb"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(25 6 * * ? *)"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      InstanceIds = [aws_instance.mongodb.id]
    })
  }
}

resource "aws_scheduler_schedule" "stop_eks_nodes" {
  name       = "${var.project_name}-stop-eks-nodes"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(10 6 * * ? *)"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:eks:updateNodegroupConfig"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      ClusterName   = module.eks.cluster_name
      NodegroupName = split(":", module.eks.eks_managed_node_groups["default"].node_group_id)[1]
      ScalingConfig = {
        MinSize     = 0
        DesiredSize = 0
      }
    })
  }
}

resource "aws_scheduler_schedule" "start_eks_nodes" {
  name       = "${var.project_name}-start-eks-nodes"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(25 6 * * ? *)"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:eks:updateNodegroupConfig"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      ClusterName   = module.eks.cluster_name
      NodegroupName = split(":", module.eks.eks_managed_node_groups["default"].node_group_id)[1]
      ScalingConfig = {
        MinSize     = 0
        DesiredSize = 2
      }
    })
  }
}
