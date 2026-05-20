#!/usr/bin/env python3
import boto3, time, random, logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TODAY = datetime.utcnow().strftime("%Y%m%d")
GAMES = [
    {"game_id": f"NYK-BOS-{TODAY}", "home": "Knicks", "away": "Celtics"},
    {"game_id": f"LAL-GSW-{TODAY}", "home": "Lakers", "away": "Warriors"},
]

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('scoutcloud-live-scores')
    updated = 0
    for game in GAMES:
        table.put_item(Item={
            'game_id':    game['game_id'],
            'home_team':  game['home'],
            'away_team':  game['away'],
            'home_score': random.randint(85, 130),
            'away_score': random.randint(85, 130),
            'quarter':    random.randint(1, 4),
            'status':     'live',
            'updated_at': datetime.utcnow().isoformat(),
            'expires_at': int(time.time()) + 10800,
        })
        updated += 1
        logger.info(f"Updated: {game['home']} vs {game['away']}")
    return {"statusCode": 200, "updated": updated}
