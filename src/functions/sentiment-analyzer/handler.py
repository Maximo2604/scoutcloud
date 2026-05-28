#!/usr/bin/env python3
import boto3, json, logging, uuid
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_comprehend_client():
    return boto3.client("comprehend", region_name="us-east-1")

def get_dynamodb_resource():
    return boto3.resource("dynamodb", region_name="us-east-1")

def analyze_sentiment(text, comprehend=None):
    if comprehend is None:
        comprehend = get_comprehend_client()
    response = comprehend.detect_sentiment(
        Text=text,
        LanguageCode="en",
    )
    return {
        "sentiment": response["Sentiment"],
        "scores": {
            "positive": round(response["SentimentScore"]["Positive"], 4),
            "negative": round(response["SentimentScore"]["Negative"], 4),
            "neutral":  round(response["SentimentScore"]["Neutral"],  4),
            "mixed":    round(response["SentimentScore"]["Mixed"],    4),
        }
    }

def lambda_handler(event, context, comprehend=None, dynamodb=None):
    if dynamodb is None:
        dynamodb = get_dynamodb_resource()
    table = dynamodb.Table("scoutcloud-fan-sentiment")
    results = []
    for comment in event.get("comments", []):
        text    = comment.get("text", "")
        user_id = comment.get("user_id", "anonymous")
        if not text:
            continue
        analysis = analyze_sentiment(text, comprehend)
        comment_id = str(uuid.uuid4())
        table.put_item(Item={
            "comment_id":  comment_id,
            "user_id":     user_id,
            "text":        text[:500],
            "sentiment":   analysis["sentiment"],
            "scores":      analysis["scores"],
            "analyzed_at": datetime.utcnow().isoformat(),
        })
        logger.info(json.dumps({
            "event": "sentiment_analyzed",
            "comment_id": comment_id,
            "sentiment": analysis["sentiment"],
        }))
        results.append({"comment_id": comment_id, "sentiment": analysis["sentiment"]})
    return {"analyzed": len(results), "results": results}
