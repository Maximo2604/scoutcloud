resource "aws_backup_vault" "main" {
  name        = "scoutcloud-backups"
  kms_key_arn = aws_kms_key.rds.arn
  tags        = local.common_tags
}

resource "aws_backup_plan" "main" {
  name = "scoutcloud-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * * *)"

    lifecycle {
      delete_after = 30
    }

    copy_action {
      lifecycle { delete_after = 7 }
      destination_vault_arn = "arn:aws:backup:us-west-2:${data.aws_caller_identity.current.account_id}:backup-vault:Default"
    }
  }

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_backup_selection" "main" {
  name         = "scoutcloud-resources"
  plan_id      = aws_backup_plan.main.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = "scoutcloud"
  }
}

resource "aws_iam_role" "backup" {
  name = "scoutcloud-backup-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "backup.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

output "backup_role_arn" { value = aws_iam_role.backup.arn }
