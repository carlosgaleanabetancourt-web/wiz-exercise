resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-security"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# WAF Protection"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "WAF Allowed vs Blocked"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "ALL", { label = "Allowed", color = "#2ca02c" }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "ALL", { label = "Blocked", color = "#d62728" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "WAF Blocks by Rule"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "${var.project_name}-common-rules", { label = "Common Rules" }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "${var.project_name}-bad-inputs", { label = "Bad Inputs" }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "${var.project_name}-sqli", { label = "SQLi" }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "${var.project_name}-rate-limit", { label = "Rate Limit" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "WAF Block Rate (%)"
          region = var.aws_region
          period = 300
          metrics = [
            [{ expression = "100 * blocked / (allowed + blocked)", label = "Block Rate %", id = "rate" }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "ALL", { id = "blocked", visible = false, stat = "Sum" }],
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.aws_region, "Rule", "ALL", { id = "allowed", visible = false, stat = "Sum" }],
          ]
          view = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 7
        width  = 24
        height = 1
        properties = {
          markdown = "# ALB Performance"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 6
        height = 6
        properties = {
          title  = "Request Count"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"RequestCount\"', 'Sum', 300)", label = "", id = "requests" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 8
        width  = 6
        height = 6
        properties = {
          title  = "Response Time (p50 / p99)"
          region = var.aws_region
          period = 300
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"TargetResponseTime\"', 'p50', 300)", label = "p50", id = "p50" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"TargetResponseTime\"', 'p99', 300)", label = "p99", id = "p99" }],
          ]
          view = "timeSeries"
          yAxis = {
            left = {
              label = "seconds"
              min   = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 6
        height = 6
        properties = {
          title  = "HTTP Errors"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"HTTPCode_ELB_4XX_Count\"', 'Sum', 300)", label = "ALB 4xx", id = "elb4xx", color = "#ff9900" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"HTTPCode_ELB_5XX_Count\"', 'Sum', 300)", label = "ALB 5xx", id = "elb5xx", color = "#d62728" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"HTTPCode_Target_4XX_Count\"', 'Sum', 300)", label = "Target 4xx", id = "tgt4xx", color = "#ffcc00" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"HTTPCode_Target_5XX_Count\"', 'Sum', 300)", label = "Target 5xx", id = "tgt5xx", color = "#cc0000" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 8
        width  = 6
        height = 6
        properties = {
          title  = "Healthy Targets"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,TargetGroup,LoadBalancer} MetricName=\"HealthyHostCount\"', 'Average', 300)", label = "Healthy", id = "healthy", color = "#2ca02c" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,TargetGroup,LoadBalancer} MetricName=\"UnHealthyHostCount\"', 'Average', 300)", label = "Unhealthy", id = "unhealthy", color = "#d62728" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 14
        width  = 24
        height = 1
        properties = {
          markdown = "# Application (EKS Pods)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 15
        width  = 6
        height = 6
        properties = {
          title  = "Pod CPU Utilization"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "PodName", "tasky", "ClusterName", module.eks.cluster_name, "Namespace", "wiz-exercise", { label = "tasky CPU %" }],
          ]
          view = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 15
        width  = 6
        height = 6
        properties = {
          title  = "Pod Memory Utilization"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["ContainerInsights", "pod_memory_utilization", "PodName", "tasky", "ClusterName", module.eks.cluster_name, "Namespace", "wiz-exercise", { label = "tasky Memory %" }],
          ]
          view = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 15
        width  = 6
        height = 6
        properties = {
          title  = "Pod Network (bytes/sec)"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["ContainerInsights", "pod_network_rx_bytes", "PodName", "tasky", "ClusterName", module.eks.cluster_name, "Namespace", "wiz-exercise", { label = "RX bytes" }],
            ["ContainerInsights", "pod_network_tx_bytes", "PodName", "tasky", "ClusterName", module.eks.cluster_name, "Namespace", "wiz-exercise", { label = "TX bytes" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 15
        width  = 6
        height = 6
        properties = {
          title  = "Pod Restart Count"
          region = var.aws_region
          stat   = "Maximum"
          period = 300
          metrics = [
            ["ContainerInsights", "pod_number_of_container_restarts", "PodName", "tasky", "ClusterName", module.eks.cluster_name, "Namespace", "wiz-exercise", { label = "Restarts" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 21
        width  = 24
        height = 1
        properties = {
          markdown = "# Infrastructure (MongoDB EC2 + EKS Nodes)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 22
        width  = 6
        height = 6
        properties = {
          title  = "MongoDB CPU"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.mongodb.id, { label = "CPU %" }],
          ]
          view = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 22
        width  = 6
        height = 6
        properties = {
          title  = "MongoDB Network"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.mongodb.id, { label = "Network In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.mongodb.id, { label = "Network Out" }],
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 22
        width  = 6
        height = 6
        properties = {
          title  = "EKS Node Count & Utilization"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["ContainerInsights", "cluster_node_count", "ClusterName", module.eks.cluster_name, { label = "Node Count", yAxis = "right" }],
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", module.eks.cluster_name, { label = "Node CPU %" }],
            ["ContainerInsights", "node_memory_utilization", "ClusterName", module.eks.cluster_name, { label = "Node Memory %" }],
          ]
          view = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
            right = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 22
        width  = 6
        height = 6
        properties = {
          title  = "MongoDB Status"
          region = var.aws_region
          stat   = "Maximum"
          period = 300
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.mongodb.id, { label = "Status Check Failed", color = "#d62728" }],
            ["AWS/EC2", "StatusCheckFailed_Instance", "InstanceId", aws_instance.mongodb.id, { label = "Instance Check Failed", color = "#ff9900" }],
            ["AWS/EC2", "StatusCheckFailed_System", "InstanceId", aws_instance.mongodb.id, { label = "System Check Failed", color = "#cc0000" }],
          ]
          view = "timeSeries"
        }
      },
    ]
  })
}
