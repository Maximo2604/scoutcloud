#!/usr/bin/env python3
import boto3, time, random, logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TODAY = datetime.utcnow().strftime("%Y%m%d")
GAMES = [
    {"game_id": f"NYK-BOS-{TODAY}", "home": "Knicks", "away": "Celtics"},
    {"game_id": f"LAL-GSW-{TODAY}", "home": "Lakers", "away": "Warriors"},
    {"game_id": f"MIA-CHI-{TODAY}", "home": "Heat", "away": "Bulls"},
]

def update_score(dynamodb, table_name, game):
    table = dynamodb.Table(table_name)
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
    logger.info(f"Updated: {game['home']} vs {game['away']}")

def main():
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    logger.info("Score fetcher starting...")
    while True:
        for game in GAMES:
            update_score(dynamodb, 'scoutcloud-live-scores', game)
        logger.info("Scores updated. Sleeping 60 seconds...")
        time.sleep(60)

if __name__ == '__main__':
    main()
