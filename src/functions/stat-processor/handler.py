#!/usr/bin/env python3
import boto3, json, logging, os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns', region_name='us-east-1')

PLAYER_ALERTS_TOPIC = os.environ.get('PLAYER_ALERTS_TOPIC_ARN', '')
POINTS_THRESHOLD = 30

def check_player_performance(game_data):
    players = game_data.get('players', [])
    alerts = []
    for player in players:
        points = player.get('points', 0)
        if points >= POINTS_THRESHOLD:
            alerts.append(player)
    return alerts

def publish_player_alert(player, game_data):
    message = (
        f"PLAYER ALERT: {player['name']} scored {player['points']} points!\n"
        f"Game: {game_data.get('away_team', '?')} @ {game_data.get('home_team', '?')}\n"
        f"Score: {game_data.get('away_score', '?')}-{game_data.get('home_score', '?')}\n"
        f"Time: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}"
    )
    sns.publish(
        TopicArn=PLAYER_ALERTS_TOPIC,
        Subject=f"ScoutCloud: {player['name']} scored {player['points']} points!",
        Message=message
    )
    logger.info(json.dumps({
        'event': 'player_alert_published',
        'player': player['name'],
        'points': player['points'],
        'game_id': game_data.get('game_id'),
        'timestamp': datetime.utcnow().isoformat()
    }))

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
    if PLAYER_ALERTS_TOPIC:
        alerts = check_player_performance(game_data)
        for player in alerts:
            publish_player_alert(player, game_data)

    logger.info(json.dumps({
        'event': 'stat_processed',
        'game_id': game_id,
        'status': 'success',
        'player_alerts': len(check_player_performance(game_data)) if PLAYER_ALERTS_TOPIC else 0,
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
