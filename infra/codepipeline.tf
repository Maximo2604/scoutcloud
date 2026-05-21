resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "scoutcloud-pipeline-artifacts-${random_id.bucket_suffix.hex}"
}

resource "aws_iam_role" "codepipeline" {
  name = "scoutcloud-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_scoped" {
  name = "scoutcloud-codepipeline-policy"
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["codepipeline:*", "codebuild:*"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"], Resource = [aws_s3_bucket.codepipeline_artifacts.arn, "${aws_s3_bucket.codepipeline_artifacts.arn}/*"] },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }
    ]
  })
}

resource "aws_codebuild_project" "terraform_plan" {
  name         = "scoutcloud-terraform-plan"
  service_role = aws_iam_role.codepipeline.arn
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
version: 0.2
phases:
  install:
    commands:
      - cd infra && terraform init
  build:
    commands:
      - terraform plan
EOF
  }
}
