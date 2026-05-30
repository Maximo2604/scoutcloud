# ScoutCloud Interview Prep

## Question 1: Walk me through ScoutCloud

A Knicks fan opens ScoutCloud. CloudFront serves the static site from the nearest edge location. When they check live scores, an API call goes through CloudFront to ALB to EC2 to DynamoDB. Scores update automatically every 5 minutes via Lambda and EventBridge. A premium scout logs in via Cognito, gets a JWT, and queries advanced stats from our RDS PostgreSQL database.

The platform started as a single EC2 instance with CSV files and evolved into a Well-Architected multi-service platform across 35+ AWS services serving 15,000 users.

## Question 2: Why DynamoDB for live scores instead of RDS?

Access pattern: high-volume, single-key lookups at sub-10ms latency. DynamoDB is designed for exactly this. RDS cannot serve 50,000 concurrent score requests at consistent millisecond latency. RDS is used for complex relational queries like player career stats and game history where we need JOINs and aggregations.

## Question 3: How do you handle production deployments without downtime?

Infrastructure changes go through GitHub Actions: PR opens, terraform plan is posted as a PR comment, human reviews the plan, merges, and terraform apply runs. Application deployments use ALB and ASG with rolling updates. New instances launch, pass health checks on the /health endpoint, then old instances are drained and terminated. Zero downtime because the ALB never routes traffic to unhealthy instances.

## Question 4: How did you secure the platform?

Defense in depth across multiple layers:
- WAF at the CloudFront layer blocks SQL injection and rate limits to 1000 requests per 5 minutes
- VPC with three tiers: ALB in public, EC2 in private, RDS in isolated subnet unreachable from internet
- GuardDuty for continuous threat detection
- KMS encryption at rest for RDS
- Secrets Manager for database credentials instead of environment variables
- Pre-commit hooks with checkov and terraform_fmt
- GitLab CI security stage blocks merges on HIGH severity findings
- Zero credentials ever committed to git

## Question 5: What would you improve with more time?

Cross-region active-active deployment for the Game 7 scenario. Currently our RTO for a us-east-1 outage is 4+ hours. I would deploy a second region in us-west-2 and use Route53 latency routing with automatic failover. I would also add distributed tracing with AWS X-Ray to reduce mean time to resolution during incidents. Finally, I would implement blue-green deployments using CodeDeploy to make application rollbacks instantaneous instead of requiring a new ASG cycle.

## Key Numbers to Remember

- 35+ AWS services used hands-on
- 18 chapters completed with challenges
- 30+ merged PRs in GitHub
- 2 Lambda functions for AI: Rekognition photo tagger, Comprehend sentiment analyzer
- 6 total Lambda functions deployed
- VPC CIDR: 10.0.0.0/16
- ASG: min 2, max 6 instances
- RDS: db.t3.micro PostgreSQL
- EKS: 2 t3.small nodes, Kubernetes 1.31
- Monthly cost: approximately $51
- RTO for instance failure: under 5 minutes
- RTO for full region failure: 4+ hours
- RPO: 24 hours (daily backups)
