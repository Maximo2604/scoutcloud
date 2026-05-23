data "archive_file" "score_updater" {
  type        = "zip"
  source_dir  = "../src/functions/score-updater"
  output_path = "/tmp/score-updater.zip"
}

resource "aws_iam_role" "lambda" {
  name = "scoutcloud-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "sqs-access"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.stat_processing.arn
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
      Resource = aws_dynamodb_table.live_scores.arn
    }]
  })
}

resource "aws_lambda_function" "score_updater" {
  filename         = data.archive_file.score_updater.output_path
  function_name    = "scoutcloud-score-updater"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.score_updater.output_base64sha256
  timeout          = 30
  tags             = { Project = "scoutcloud" }
}

resource "aws_cloudwatch_event_rule" "every_5_minutes" {
  name                = "scoutcloud-score-update"
  description         = "Trigger score updater every 5 minutes"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "score_updater" {
  rule      = aws_cloudwatch_event_rule.every_5_minutes.name
  target_id = "scoutcloud-score-updater"
  arn       = aws_lambda_function.score_updater.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.score_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_5_minutes.arn
}
