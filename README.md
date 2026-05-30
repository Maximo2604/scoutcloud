# ScoutCloud — NBA Intelligence Platform

[![Deploy Static Assets](https://github.com/Maximo2604/scoutcloud/actions/workflows/deploy-static.yml/badge.svg)](https://github.com/Maximo2604/scoutcloud/actions/workflows/deploy-static.yml)
[![Terraform CI/CD](https://github.com/Maximo2604/scoutcloud/actions/workflows/terraform.yml/badge.svg)](https://github.com/Maximo2604/scoutcloud/actions/workflows/terraform.yml)

A production-grade real-time NBA intelligence platform built on AWS. Started as a single EC2 instance with CSV files. Evolved into a Well-Architected, multi-service platform serving 15,000 users across 35+ AWS services.

**Live:** https://app.scoutcloud.dev

## What It Does

**For fans (free tier)**
- Live game scores updated every 5 minutes via Lambda and EventBridge
- Player statistics from PostgreSQL (career averages, season splits)
- Player photos automatically tagged using Amazon Rekognition AI

**For NBA front offices ($499/month)**
- Advanced shot chart data by defensive matchup
- 30+ point player alert notifications via SNS
- Authenticated API access via Cognito JWT tokens
- Fan sentiment analysis using Amazon Comprehend

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| Compute | EC2 (ASG 2-6 instances), ECS Fargate, Lambda (6 functions) |
| Database | RDS PostgreSQL, DynamoDB |
| Storage | Amazon S3, EBS |
| CDN | CloudFront (400+ edge locations), Route53 |
| Security | WAF, KMS, Secrets Manager, HashiCorp Vault |
| CI/CD | GitHub Actions (OIDC), GitLab CI, AWS CodePipeline |
| IaC | Terraform (modules, remote state, S3 backend) |
| Monitoring | CloudWatch, Prometheus, Grafana |
| AI/ML | Rekognition (photo tagging), Comprehend (sentiment) |
| Orchestration | EKS (Kubernetes 1.31), RBAC |
| Config Mgmt | Ansible |
| Auth | Amazon Cognito, API Gateway JWT authorizer |
| Networking | Custom VPC, 3-tier subnets, NAT Gateway, VPC Endpoints |
| Backup | AWS Backup (daily, 30-day retention, cross-region) |
| Cost | AWS Budgets, Cost Explorer, auto-stop Lambda |

## Architecture

Three-tier VPC architecture:
- Public subnets: ALB, NAT Gateway
- Private subnets: EC2 ASG, ECS Fargate, Lambda
- Isolated subnets: RDS PostgreSQL (not publicly accessible)

Traffic flow: User -> CloudFront (WAF) -> ALB -> EC2 -> RDS/DynamoDB

## Key Engineering Decisions

- ADR-001: AWS over Azure/GCP for ecosystem depth
- ADR-002: us-east-1 for lowest latency to NBA arenas on East Coast
- DynamoDB for live scores (sub-10ms single-key lookups)
- RDS for player stats (complex JOINs and aggregations)
- CloudFront in front of ALB to absorb Game 7 traffic spikes

## Deployment

git clone git@github.com:Maximo2604/scoutcloud.git
cd scoutcloud/scoutcloud.dev
make init
make apply

Prerequisites: AWS CLI configured, Terraform 1.x, Docker running.

## AWS Cost Estimate

| Service | Monthly Cost |
|---------|-------------|
| EC2 (2x t3.micro, ASG) | $17 |
| RDS db.t3.micro PostgreSQL | $15 |
| Application Load Balancer | $16 |
| CloudFront (10GB transfer) | $1 |
| Lambda (1M invocations) | $0.20 |
| DynamoDB (PAY_PER_REQUEST) | $2 |
| **Total** | **~$51/month** |

Cost optimization: Auto-stop Lambda shuts down dev instances at 8pm ET saving ~$8/month.

## Security

- WAF blocks SQL injection (tested: 403 on injection probe)
- RDS in isolated subnet, publicly_accessible = false
- KMS encryption at rest for RDS
- Secrets Manager for all credentials
- Pre-commit hooks: terraform_fmt, terraform_validate, checkov
- GitLab CI security gate blocks HIGH severity findings

## Reliability

- RTO for single instance failure: < 5 minutes (ASG auto-replaces)
- RTO for full region failure: 4+ hours (documented in DR runbook)
- RPO: 24 hours (daily AWS Backup with cross-region copy to us-west-2)
- Chaos engineering: FIS experiment template for instance termination testing

## Well-Architected Review

Reviewed against all 6 AWS Well-Architected pillars. See docs/runbooks/ for operational procedures.
