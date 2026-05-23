resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "ScoutCloud-Operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "EC2 CPU Utilization"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "scoutcloud-asg"]]
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
          region  = "us-east-1"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count and 5xx Errors"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/scoutcloud-alb/fbfb31079a3cd655"],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "app/scoutcloud-alb/fbfb31079a3cd655"]
          ]
          period = 60
          stat   = "Sum"
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Score Updater Invocations"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "scoutcloud-score-updater"],
            ["AWS/Lambda", "Errors", "FunctionName", "scoutcloud-score-updater"]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "DynamoDB Latency"
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "scoutcloud-live-scores", "Operation", "PutItem"],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "scoutcloud-live-scores", "Operation", "GetItem"]
          ]
          period = 60
          stat   = "Average"
          region = "us-east-1"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "scoutcloud-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU above 80% for 5 minutes"
  dimensions          = { AutoScalingGroupName = "scoutcloud-asg" }
  alarm_actions       = [aws_sns_topic.score_alerts.arn]
  ok_actions          = [aws_sns_topic.score_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "scoutcloud-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 5xx errors per minute"
  dimensions          = { LoadBalancer = "app/scoutcloud-alb/fbfb31079a3cd655" }
  alarm_actions       = [aws_sns_topic.score_alerts.arn]
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "scoutcloud-cloudtrail-${random_id.bucket_suffix.hex}"
  tags   = { Name = "scoutcloud-cloudtrail", Project = "scoutcloud" }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/cloudtrail/AWSLogs/878598436021/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "scoutcloud-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]
  tags                          = { Project = "scoutcloud" }
}
