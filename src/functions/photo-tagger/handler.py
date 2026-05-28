#!/usr/bin/env python3
import boto3, json, logging, os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_rekognition_client():
    return boto3.client("rekognition", region_name="us-east-1")

def get_dynamodb_resource():
    return boto3.resource("dynamodb", region_name="us-east-1")

def analyze_photo(s3_bucket, s3_key, rekognition=None):
    if rekognition is None:
        rekognition = get_rekognition_client()
    label_response = rekognition.detect_labels(
        Image={"S3Object": {"Bucket": s3_bucket, "Name": s3_key}},
        MaxLabels=10,
        MinConfidence=80.0,
    )
    face_response = rekognition.detect_faces(
        Image={"S3Object": {"Bucket": s3_bucket, "Name": s3_key}},
        Attributes=["DEFAULT"],
    )
    labels = [
        {"name": label["Name"], "confidence": round(label["Confidence"], 2)}
        for label in label_response["Labels"]
    ]
    return {
        "labels": labels,
        "face_count": len(face_response["FaceDetails"]),
        "is_basketball_photo": any(
            label["name"] in ["Basketball", "Sports", "Person", "Ball"]
            for label in labels
        ),
    }

def store_results(photo_key, analysis, dynamodb=None):
    if dynamodb is None:
        dynamodb = get_dynamodb_resource()
    table = dynamodb.Table("scoutcloud-photo-tags")
    table.put_item(Item={
        "photo_key":    photo_key,
        "analyzed_at":  datetime.utcnow().isoformat(),
        "labels":       analysis["labels"],
        "face_count":   analysis["face_count"],
        "is_basketball": analysis["is_basketball_photo"],
    })

def lambda_handler(event, context, rekognition=None, dynamodb=None):
    processed = 0
    for record in event["Records"]:
        s3_bucket = record["s3"]["bucket"]["name"]
        s3_key    = record["s3"]["object"]["key"]
        if not s3_key.startswith("players/photos/"):
            logger.info(f"Skipping non-photo file: {s3_key}")
            continue
        logger.info(json.dumps({
            "event": "photo_analysis_started",
            "bucket": s3_bucket,
            "key": s3_key,
        }))
        analysis = analyze_photo(s3_bucket, s3_key, rekognition)
        store_results(s3_key, analysis, dynamodb)
        logger.info(json.dumps({
            "event": "photo_analysis_complete",
            "key": s3_key,
            "labels": [l["name"] for l in analysis["labels"]],
            "faces": analysis["face_count"],
        }))
        processed += 1
    return {"processed": processed}
