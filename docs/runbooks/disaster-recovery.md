# ScoutCloud Disaster Recovery Runbook

## RTO and RPO

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single EC2 instance failure | < 5 minutes | 0 (no data loss) |
| Full AZ failure | < 5 minutes | 0 (ALB routes to other AZ) |
| RDS primary failure | < 5 minutes | < 5 minutes (RDS Multi-AZ) |
| S3 data corruption | < 30 minutes | up to 24 hours |
| Full us-east-1 outage | > 4 hours | up to 24 hours |
| Accidental terraform destroy | < 2 hours | up to 24 hours |

## Scenario 1: Single EC2 Instance Failure

Detection: CloudWatch alarm fires -> SNS email alert
Action: None required — Auto Scaling Group replaces the instance automatically
Verify: aws autoscaling describe-auto-scaling-groups shows InService instances = 2

## Scenario 2: RDS Database Corruption

1. Identify the corruption timeframe from CloudTrail logs
2. List available recovery points:
   aws backup list-recovery-points-by-resource --resource-arn RDS_INSTANCE_ARN
3. Start restore job to a new DB instance:
   aws backup start-restore-job --recovery-point-arn RECOVERY_POINT_ARN --metadata '{"DBInstanceIdentifier":"scoutcloud-db-restored"}'
4. Update Terraform to point to the restored instance
5. Verify application connectivity
6. Delete the corrupted instance

## Scenario 3: Accidental terraform destroy

1. All infrastructure is in Terraform — run terraform apply to rebuild
2. For data: restore from AWS Backup (see Scenario 2)
3. Estimated rebuild time: 30-45 minutes

## Scenario 4: Full Region Failure

1. Declare incident and notify stakeholders
2. Switch Cloudflare DNS to point to static maintenance page on S3
3. Initiate restore in us-west-2 from cross-region backup copies
4. Update Terraform workspace to us-west-2
5. Run terraform apply in us-west-2
6. Update Cloudflare DNS to new region ALB
7. Estimated RTO: 4+ hours

## Contact Information

On-call: engineering@scoutcloud.dev
Escalation: marcus@scoutcloud.dev
AWS Support: console.aws.amazon.com/support
