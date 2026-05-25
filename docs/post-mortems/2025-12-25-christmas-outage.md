# Post-Mortem: Christmas Day Outage
**Date:** December 25, 2025  
**Duration:** 2h 47m (14:13 UTC - 17:00 UTC)  
**Severity:** SEV-1 - Complete service unavailability  
**Author:** ScoutCloud Engineering  
**Status:** Resolved  

---

## Summary

On Christmas Day 2025, ScoutCloud experienced a complete outage lasting 2 hours and 47 minutes during peak NBA game traffic. A single EC2 instance running the Flask application became CPU-saturated under unexpected load, causing the platform to stop serving requests. At the time, there was no load balancer, no auto-scaling, and no monitoring in place to detect or respond to the issue.

---

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 13:00 | NBA Christmas Day games tip off. Traffic begins increasing. |
| 14:13 | CPU utilization on the single EC2 instance reaches 100%. |
| 14:15 | gunicorn worker processes become unresponsive. New requests begin timing out. |
| 14:19 | First user complaint received via Twitter - ScoutCloud is down. |
| 14:31 | Diana Chen emails Marcus: platform is unreachable during the biggest NBA day of the year. |
| 14:45 | On-call engineer notified via phone. No monitoring alerts had fired - none existed. |
| 15:10 | Engineer SSHs into the instance. Discovers CPU at 100%, gunicorn not responding. |
| 15:22 | gunicorn manually restarted. Platform recovers briefly before crashing again under load. |
| 15:45 | Decision made to restart the instance and block all but essential traffic. |
| 16:30 | Instance restarted. Traffic manually throttled. Platform partially restored. |
| 17:00 | Full service restored at 50% of normal traffic capacity. |

---

## Root Cause

A single t2.micro EC2 instance was serving all production traffic with no horizontal scaling capability. On Christmas Day, NBA game traffic increased 8x above normal levels. The instance CPU reached 100% saturation, causing gunicorn worker processes to queue requests indefinitely. New connections timed out. The instance became effectively unresponsive within 2 minutes of reaching saturation.

---

## Contributing Factors

1. No load balancer - All traffic routed directly to one instance. No redundancy.
2. No auto-scaling - No mechanism to add capacity under load.
3. No monitoring or alerting - CPU saturation went undetected for 32 minutes.
4. No health checks - No automated detection that the application had stopped responding.
5. Single point of failure - One instance failure meant 100% outage.
6. No runbook - On-call engineer had no documented procedure to follow.

---

## Impact

- Duration: 2 hours 47 minutes of complete unavailability
- Users affected: 100% of active users during NBA Christmas Day games
- Revenue impact: Estimated $2,400 in lost subscription revenue
- Reputational impact: 847 complaints on Twitter, Diana Chen enterprise contract put on hold
- Data impact: Live score updates stopped for 2h 47m. DynamoDB records show gap in game data.

---

## Resolution

The immediate resolution was a manual instance restart with traffic throttling. This was a temporary measure to restore partial service while a proper solution was planned.

---

## Corrective Actions

### 1. Application Load Balancer with Auto Scaling Group (Chapter 5)
Terraform resource: aws_autoscaling_group.web in infra/alb.tf  
Replaced single EC2 instance with an ALB distributing traffic across minimum 2 instances, scaling to 6 under load. A single instance failure no longer causes an outage.

### 2. CPU Utilization Alarm (Chapter 12)
Terraform resource: aws_cloudwatch_metric_alarm.high_cpu in infra/monitoring.tf  
CloudWatch alarm fires when ASG average CPU exceeds 80% for 5 consecutive minutes. Alert delivered via aws_sns_topic.score_alerts. On-call engineer notified before users are impacted.

### 3. ALB 5xx Error Rate Alarm (Chapter 12)
Terraform resource: aws_cloudwatch_metric_alarm.error_rate in infra/monitoring.tf  
CloudWatch alarm fires when more than 10 five-hundred errors occur per minute.

### 4. ALB Health Checks (Chapter 5)
Terraform resource: aws_lb_target_group.web health check in infra/alb.tf  
ALB performs health checks against /health every 30 seconds. Unhealthy instances automatically removed after 3 consecutive failures.

### 5. Target Tracking Auto Scaling Policy (Chapter 5)
Terraform resource: aws_autoscaling_policy.scale_up in infra/alb.tf  
ASG automatically adds instances when average CPU exceeds 60%. The Christmas Day spike would have triggered scale-out before saturation.

### 6. CloudWatch Operations Dashboard (Chapter 12)
Terraform resource: aws_cloudwatch_dashboard.main in infra/monitoring.tf  
Real-time dashboard showing EC2 CPU, ALB request count, Lambda invocations, and DynamoDB latency.

### 7. Dead Letter Queue Alarm (Chapter 11)
Terraform resource: aws_cloudwatch_metric_alarm.dlq_messages in infra/messaging.tf  
Any failed score processing triggers an SNS alert. Silent failures are now impossible.

### 8. HTTPS and CloudFront (Chapters 5 and 10)
Terraform resources: aws_cloudfront_distribution.main, aws_acm_certificate.main  
Static assets served from CloudFront edge locations. Origin load reduced significantly.

---

## CloudWatch Log Insights Queries

Detect CPU saturation patterns:

fields @timestamp, @message
| filter @message like /cpu/
| stats count(*) as high_cpu_events by bin(5m)
| sort @timestamp desc
| limit 20

Detect gunicorn worker exhaustion:

fields @timestamp, @message
| filter @message like /WORKER TIMEOUT/
| stats count(*) as timeouts by bin(1m)
| sort @timestamp desc
| limit 20

Detect request queue buildup:

fields @timestamp, @message
| filter @message like /upstream timed out/
| stats count(*) as upstream_timeouts by bin(1m)
| having upstream_timeouts > 5
| sort @timestamp desc

---

## Lessons Learned

1. A single EC2 instance is not a production architecture. Redundancy is not optional.
2. Monitoring must exist before incidents, not after. 32 minutes of undetected CPU saturation is unacceptable.
3. Auto-scaling is cheaper than downtime. The cost of 2 additional t3.micro instances is a fraction of the revenue lost in one outage.
4. Health checks save on-call engineers. Automated detection beats a Twitter complaint every time.
5. Post-mortems are blameless. The system failed, not the people. The corrective actions fix the system.

---

This post-mortem was written retrospectively using monitoring infrastructure built in Chapters 5-12 of the ScoutCloud platform rebuild. All corrective actions have been implemented and verified in production.
