# main.tf — ScoutCloud IAM configuration
terraform {
  required_version = ">= 1.0"
  backend "s3" {
    bucket         = "scoutcloud-tfstate-878598436021"
    key            = "scoutcloud/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "scoutcloud-tf-locks"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
}

resource "aws_iam_role" "github_actions" {
  name = "scoutcloud-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:Maximo2604/scoutcloud:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_s3" {
  name = "scoutcloud-s3-sync"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
    }]
  })
}

output "github_actions_role_arn" { value = aws_iam_role.github_actions.arn }

module "compute" {
  source            = "./modules/compute"
  ami_id            = data.aws_ami.amazon_linux_2023.id
  key_name          = "scoutcloud-key"
  security_group_id = aws_security_group.web.id
  subnet_ids        = data.aws_subnets.default.ids
  project           = "scoutcloud"
}
