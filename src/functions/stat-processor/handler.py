#!/usr/bin/env python3
import boto3, json, logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

def process_score_update(game_data):
    table = dynamodb.Table('scoutcloud-live-scores')
    game_id = game_data.get('game_id', 'unknown')
    table.update_item(
        Key={'game_id': game_id},
        UpdateExpression='SET processed_at = :ts, stat_status = :status',
        ExpressionAttributeValues={
            ':ts': datetime.utcnow().isoformat(),
            ':status': 'processed',
        }
    )
    logger.info(json.dumps({
        'event': 'stat_processed',
        'game_id': game_id,
        'status': 'success',
        'timestamp': datetime.utcnow().isoformat(),
    }))

def lambda_handler(event, context):
    processed = 0
    failed = 0
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            if 'Message' in body:
                game_data = json.loads(body['Message'])
            else:
                game_data = body
            process_score_update(game_data)
            processed += 1
        except Exception as e:
            logger.error(json.dumps({
                'event': 'stat_processing_failed',
                'error': str(e),
                'record': record['body'][:200],
                'timestamp': datetime.utcnow().isoformat(),
            }))
            failed += 1
            raise
    return {'processed': processed, 'failed': failed}
