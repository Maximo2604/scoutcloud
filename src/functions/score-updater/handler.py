#!/usr/bin/env python3
import boto3, time, random, logging, json
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TODAY = datetime.utcnow().strftime("%Y%m%d")
GAMES = [
    {"game_id": f"NYK-BOS-{TODAY}", "home": "Knicks", "away": "Celtics"},
    {"game_id": f"LAL-GSW-{TODAY}", "home": "Lakers", "away": "Warriors"},
]

def log(event, game_id, status, error_message=None):
    entry = {
        "event": event,
        "game_id": game_id,
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
    }
    if error_message:
        entry["error_message"] = error_message
    logger.info(json.dumps(entry))

def lambda_handler(event, context):
    table_name = event.get("table_name", "scoutcloud-live-scores")
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)
    updated = 0

    for game in GAMES:
        try:
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
            log("score_update", game['game_id'], "success")
            updated += 1
        except Exception as e:
            log("score_update", game['game_id'], "error", str(e))

    return {"statusCode": 200, "updated": updated}
