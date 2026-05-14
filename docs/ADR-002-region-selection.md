# ADR-002: AWS Region Selection

**Date:** 2026-05-11
**Status:** Accepted

## Context
ScoutCloud needs to choose an AWS region for hosting compute, storage, and databases. The region impacts latency for users, cost, and proximity to NBA data feeds. Marcus (investor) asked: why a specific region?

## Options Considered

| Region | Pros | Cons |
|--------|------|------|
| us-east-1 (N. Virginia) | Closest to NBA HQ (NYC), lowest latency East Coast, most major arenas nearby | Slightly higher cost |
| us-west-2 (Oregon) | Good for LA market (Lakers/Clippers), lower cost | Higher latency to East Coast |
| eu-west-1 (Ireland) | Good for international, lower cost | High latency for US users |

## Decision
**us-east-1** (N. Virginia)

## Reasoning

### Data Point 1: NBA Geography
- NBA Headquarters: 645 Fifth Ave, **New York City**
- Top 5 Markets by Arena Count: Boston (1), New York (2), Chicago (1), Los Angeles (2), Miami (1)
- **4 out of 5 are East Coast** — us-east-1 serves them with lowest latency

### Data Point 2: AWS Latency
- us-east-1 to NYC: ~10ms
- us-east-1 to LA: ~70ms
- us-west-2 to NYC: ~130ms
- **us-east-1 has 13x better latency for East Coast users**

### Data Point 3: NBA Data APIs
- Most NBA statistics APIs (ESPN, official NBA.com feeds) default to us-east-1 or have primary endpoints there
- Reduces data transfer costs between services

## Consequences
- Users on West Coast (LA, Phoenix) will have ~70ms latency (acceptable)
- Cost is ~3% higher than us-west-2, but latency benefit justifies it
- Can use CloudFront (CDN) in future chapters to further reduce latency
