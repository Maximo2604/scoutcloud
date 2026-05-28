data "archive_file" "photo_tagger" {
  type        = "zip"
  source_dir  = "../src/functions/photo-tagger"
  output_path = "/tmp/photo-tagger.zip"
}

data "archive_file" "sentiment_analyzer" {
  type        = "zip"
  source_dir  = "../src/functions/sentiment-analyzer"
  output_path = "/tmp/sentiment-analyzer.zip"
}

resource "aws_dynamodb_table" "photo_tags" {
  name         = "scoutcloud-photo-tags"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "photo_key"
  attribute {
    name = "photo_key"
    type = "S"
  }
  tags = { Name = "scoutcloud-photo-tags", Project = "scoutcloud" }
}

resource "aws_dynamodb_table" "sentiment" {
  name         = "scoutcloud-fan-sentiment"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "comment_id"
  attribute {
    name = "comment_id"
    type = "S"
  }
  tags = { Name = "scoutcloud-fan-sentiment", Project = "scoutcloud" }
}

resource "aws_iam_role" "ai_lambda" {
  name = "scoutcloud-ai-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "ai_lambda" {
  name = "ai-lambda-policy"
  role = aws_iam_role.ai_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["rekognition:DetectLabels", "rekognition:DetectFaces"], Resource = "*" },
      { Effect = "Allow", Action = ["comprehend:DetectSentiment", "comprehend:DetectEntities"], Resource = "*" },
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem"], Resource = [aws_dynamodb_table.photo_tags.arn, aws_dynamodb_table.sentiment.arn] },
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.assets.arn}/*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }
    ]
  })
}

resource "aws_lambda_function" "photo_tagger" {
  filename         = data.archive_file.photo_tagger.output_path
  function_name    = "scoutcloud-photo-tagger"
  role             = aws_iam_role.ai_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.photo_tagger.output_base64sha256
  timeout          = 60
  tags             = { Project = "scoutcloud" }
}

resource "aws_lambda_function" "sentiment_analyzer" {
  filename         = data.archive_file.sentiment_analyzer.output_path
  function_name    = "scoutcloud-sentiment-analyzer"
  role             = aws_iam_role.ai_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.sentiment_analyzer.output_base64sha256
  timeout          = 60
  tags             = { Project = "scoutcloud" }
}

resource "aws_lambda_permission" "photo_tagger_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.photo_tagger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

resource "aws_s3_bucket_notification" "photo_tagger" {
  bucket = aws_s3_bucket.assets.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.photo_tagger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "players/photos/"
    filter_suffix       = ".jpg"
  }
  depends_on = [aws_lambda_permission.photo_tagger_s3]
}
