# main.tf — ScoutCloud IAM configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# A group for developers with read-only access
resource "aws_iam_group" "developers" {
  name = "scoutcloud-developers"
}

resource "aws_iam_group_policy_attachment" "developer_readonly" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
