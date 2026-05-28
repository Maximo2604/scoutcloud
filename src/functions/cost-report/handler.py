#!/usr/bin/env python3
import boto3, json, logging, os, urllib.request
from datetime import datetime, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_cost_by_environment(start_date, end_date):
    ce = boto3.client("ce", region_name="us-east-1")
    response = ce.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "TAG", "Key": "Environment"}],
    )
    results = {}
    for result in response["ResultsByTime"]:
        for group in result["Groups"]:
            env = group["Keys"][0].replace("Environment$", "") or "untagged"
            cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
            results[env] = results.get(env, 0) + cost
    return results

def get_total_cost(start_date, end_date):
    ce = boto3.client("ce", region_name="us-east-1")
    response = ce.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
    )
    total = sum(
        float(r["Total"]["UnblendedCost"]["Amount"])
        for r in response["ResultsByTime"]
    )
    return total

def format_slack_message(costs, total, start_date, end_date):
    lines = [
        f"*ScoutCloud Weekly Cost Report*",
        f"_{start_date} to {end_date}_",
        "",
        "*Cost by Environment:*",
    ]
    for env, cost in sorted(costs.items(), key=lambda x: x[1], reverse=True):
        bar = "=" * int(cost / total * 20) if total > 0 else ""
        lines.append(f"  {env:<12} ${cost:.2f}  {bar}")
    lines.append("")
    lines.append(f"*Total: ${total:.2f}*")
    if total > 40:
        lines.append(":warning: Approaching $50 monthly budget!")
    return {"text": chr(10).join(lines)}

def post_to_slack(message, webhook_url):
    data = json.dumps(message).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as response:
        return response.status

def lambda_handler(event, context):
    end_date = datetime.utcnow().strftime("%Y-%m-%d")
    start_date = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d")

    costs = get_cost_by_environment(start_date, end_date)
    total = get_total_cost(start_date, end_date)
    message = format_slack_message(costs, total, start_date, end_date)

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
    if webhook_url:
        status = post_to_slack(message, webhook_url)
        logger.info(json.dumps({"event": "slack_posted", "status": status}))
    else:
        logger.info(json.dumps({"event": "cost_report", "message": message["text"]}))

    logger.info(json.dumps({
        "event": "cost_report_complete",
        "period": f"{start_date} to {end_date}",
        "total": round(total, 2),
        "by_environment": {k: round(v, 2) for k, v in costs.items()},
    }))

    return {"total": round(total, 2), "by_environment": {k: round(v, 2) for k, v in costs.items()}}
