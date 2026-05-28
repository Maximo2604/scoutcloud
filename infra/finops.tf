# AWS Config for tag compliance
resource "aws_iam_role" "config" {
  name = "scoutcloud-config-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "config.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "scoutcloud-config"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported = true
  }
}

# Budget alarms
resource "aws_budgets_budget" "monthly" {
  name         = "scoutcloud-monthly-budget"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["marcus@scoutcloud.dev"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["marcus@scoutcloud.dev"]
  }
}

resource "aws_budgets_budget" "eks" {
  name         = "scoutcloud-eks-budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Kubernetes Service"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["marcus@scoutcloud.dev"]
  }
}

# Cost cleanup Lambda
data "archive_file" "cost_cleanup" {
  type        = "zip"
  source_dir  = "../src/functions/cost-cleanup"
  output_path = "/tmp/cost-cleanup.zip"
}

resource "aws_lambda_function" "cost_cleanup" {
  filename         = data.archive_file.cost_cleanup.output_path
  function_name    = "scoutcloud-cost-cleanup"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.cost_cleanup.output_base64sha256
  timeout          = 60
  tags             = local.common_tags
}

resource "aws_cloudwatch_event_rule" "stop_dev" {
  name                = "stop-dev-instances"
  schedule_expression = "cron(0 0 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "stop_dev" {
  rule      = aws_cloudwatch_event_rule.stop_dev.name
  target_id = "StopDevInstances"
  arn       = aws_lambda_function.cost_cleanup.arn
  input     = jsonencode({ "action" : "stop" })
}

resource "aws_cloudwatch_event_rule" "start_dev" {
  name                = "start-dev-instances"
  schedule_expression = "cron(0 13 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "start_dev" {
  rule      = aws_cloudwatch_event_rule.start_dev.name
  target_id = "StartDevInstances"
  arn       = aws_lambda_function.cost_cleanup.arn
  input     = jsonencode({ "action" : "start" })
}

resource "aws_lambda_permission" "stop_dev" {
  statement_id  = "AllowEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_dev.arn
}

resource "aws_lambda_permission" "start_dev" {
  statement_id  = "AllowEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_dev.arn
}
