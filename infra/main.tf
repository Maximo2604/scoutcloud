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

# Contractor user with read-only access
resource "aws_iam_user" "contractor" {
  name = "scoutcloud-contractor"
}

resource "aws_iam_user_policy_attachment" "contractor_readonly" {
  user       = aws_iam_user.contractor.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Create access key for contractor
resource "aws_iam_access_key" "contractor" {
  user = aws_iam_user.contractor.name
}

output "contractor_access_key_id" {
  value = aws_iam_access_key.contractor.id
}

output "contractor_secret_access_key" {
  value     = aws_iam_access_key.contractor.secret
  sensitive = true
}
