# GuardDuty requires subscription - skipped
# resource "aws_guardduty_detector" "main" {
#   enable = true
#   datasources {
#     s3_logs {
#       enable = true
#     }
#     kubernetes {
#       audit_logs {
#         enable = false
#       }
#     }
#     malware_protection {
#       scan_ec2_instance_with_findings {
#         ebs_volumes {
#           enable = true
#         }
#       }
#     }
#   }
#   tags = { Project = "scoutcloud" }
# }
#
#
resource "aws_wafv2_web_acl" "main" {
  name     = "scoutcloud-waf"
  scope    = "CLOUDFRONT"
  provider = aws.us_east_1

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-CommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-SQLiRuleSet"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "scoutcloud-waf"
    sampled_requests_enabled   = true
  }

  tags = { Project = "scoutcloud" }
}

resource "aws_kms_key" "rds" {
  description             = "ScoutCloud RDS encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "scoutcloud-rds-key", Project = "scoutcloud" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/scoutcloud-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "scoutcloud/rds/password"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.rds.arn
  tags                    = { Project = "scoutcloud" }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = "scoutadmin"
    password = var.db_password
  })
}

resource "aws_security_group" "vault" {
  name   = "scoutcloud-vault-sg"
  vpc_id = module.network.vpc_id
  ingress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "vault" {
  name = "scoutcloud-vault-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "vault_ssm" {
  role       = aws_iam_role.vault.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vault" {
  name = "scoutcloud-vault-profile"
  role = aws_iam_role.vault.name
}

resource "aws_instance" "vault" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.network.private_subnet_ids[0]
  iam_instance_profile   = aws_iam_instance_profile.vault.name
  vpc_security_group_ids = [aws_security_group.vault.id]
  user_data              = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    docker run -d --name vault --cap-add=IPC_LOCK -p 8200:8200 -e VAULT_DEV_ROOT_TOKEN_ID=scoutcloud-vault-token -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 hashicorp/vault:latest server -dev
  EOF
  tags                   = { Name = "scoutcloud-vault", Project = "scoutcloud" }
}

output "vault_instance_id" { value = aws_instance.vault.id }
