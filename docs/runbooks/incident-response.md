# ScoutCloud Incident Response Runbook

## Severity Levels

| Level | Definition | Response Time |
|-------|-----------|---------------|
| P1 | ScoutCloud completely down | 15 minutes |
| P2 | Degraded performance or partial outage | 1 hour |
| P3 | Non-customer-facing system issue | Next business day |

## P1 Response

1. Acknowledge the SNS alert within 15 minutes
2. Check CloudWatch dashboard: ScoutCloud-Operations
3. Check ALB target group health
4. Check recent deployments in GitHub Actions
5. Check RDS connectivity from EC2 via SSM
6. Escalate to Marcus if not resolved within 30 minutes

## P2 Response

1. Check CloudWatch alarms for CPU, 5xx errors, DynamoDB latency
2. Check Lambda error rates in CloudWatch
3. Review CloudTrail for recent API changes
4. Scale up ASG if CPU-bound

## Communication Templates

Internal Slack P1: INCIDENT P1 - ScoutCloud is down as of TIME. On-call engineer NAME is investigating. Next update in 15 minutes.

Status Page P1: We are aware of an issue affecting ScoutCloud. Our team is actively investigating. We will provide updates every 15 minutes.

## Post-Incident Process

1. Write post-mortem within 24 hours
2. File in docs/post-mortems/YYYY-MM-DD-incident-name.md
3. Create action items as GitHub Issues
4. Schedule 30-minute blameless post-mortem meeting

## Contact Information

| Role | Contact |
|------|---------|
| On-call engineer | engineering@scoutcloud.dev |
| Engineering Manager | marcus@scoutcloud.dev |
| AWS Support | console.aws.amazon.com/support |
