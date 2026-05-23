resource "aws_sns_topic" "score_alerts" {
  name = "scoutcloud-score-alerts"
  tags = { Name = "scoutcloud-score-alerts", Project = "scoutcloud" }
}

resource "aws_sns_topic_subscription" "diana_email" {
  topic_arn = aws_sns_topic.score_alerts.arn
  protocol  = "email"
  endpoint  = "diana.chen@example.com"
}

output "sns_topic_arn" {
  value = aws_sns_topic.score_alerts.arn
}

resource "aws_sqs_queue" "stat_processing_dlq" {
  name                      = "scoutcloud-stat-processing-dlq"
  message_retention_seconds = 1209600
  tags                      = { Name = "scoutcloud-stat-processing-dlq", Project = "scoutcloud" }
}

resource "aws_sqs_queue" "stat_processing" {
  name                       = "scoutcloud-stat-processing"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.stat_processing_dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = "scoutcloud-stat-processing", Project = "scoutcloud" }
}

resource "aws_sns_topic_subscription" "stat_processing" {
  topic_arn = aws_sns_topic.score_alerts.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.stat_processing.arn
}

resource "aws_sqs_queue_policy" "stat_processing" {
  queue_url = aws_sqs_queue.stat_processing.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.stat_processing.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_sns_topic.score_alerts.arn
        }
      }
    }]
  })
}

output "sqs_queue_url" {
  value = aws_sqs_queue.stat_processing.url
}

data "archive_file" "stat_processor" {
  type        = "zip"
  source_dir  = "../src/functions/stat-processor"
  output_path = "/tmp/stat-processor.zip"
}

resource "aws_lambda_function" "stat_processor" {
  filename         = data.archive_file.stat_processor.output_path
  function_name    = "scoutcloud-stat-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.stat_processor.output_base64sha256
  timeout          = 300
  tags             = { Project = "scoutcloud" }

  environment {
    variables = {
      PLAYER_ALERTS_TOPIC_ARN = aws_sns_topic.player_alerts.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "stat_processor" {
  event_source_arn = aws_sqs_queue.stat_processing.arn
  function_name    = aws_lambda_function.stat_processor.arn
  batch_size       = 10
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "scoutcloud-stat-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Messages in stat processing DLQ"
  dimensions = {
    QueueName = aws_sqs_queue.stat_processing_dlq.name
  }
  alarm_actions = [aws_sns_topic.score_alerts.arn]
}

resource "aws_sns_topic" "player_alerts" {
  name = "scoutcloud-player-alerts"
  tags = { Name = "scoutcloud-player-alerts", Project = "scoutcloud" }
}

resource "aws_sns_topic_subscription" "player_alerts_email" {
  topic_arn = aws_sns_topic.player_alerts.arn
  protocol  = "email"
  endpoint  = "diana.chen@example.com"
}

output "player_alerts_topic_arn" {
  value = aws_sns_topic.player_alerts.arn
}
