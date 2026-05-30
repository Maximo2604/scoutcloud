# AWS X-Ray distributed tracing
# Addresses Well-Architected HIGH finding: no distributed tracing

# Add X-Ray permissions to Lambda role
resource "aws_iam_role_policy" "lambda_xray" {
  name = "xray-write-access"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"
      ]
      Resource = "*"
    }]
  })
}

# Enable X-Ray tracing on Lambda functions
# Note: tracing_config is added to each Lambda function resource
# Lambda tracing mode: PassThrough (sample) or Active (all requests)

# X-Ray sampling rule - sample 5% of requests in dev, 100% of errors
resource "aws_xray_sampling_rule" "main" {
  rule_name      = "scoutcloud-sampling"
  priority       = 1000
  version        = 1
  reservoir_size = 5
  fixed_rate     = 0.05
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = local.common_tags
}
