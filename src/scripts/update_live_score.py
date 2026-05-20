#!/usr/bin/env python3
import boto3, argparse, time
from datetime import datetime

def update_score(game_id, home, away, home_score, away_score, quarter):
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('scoutcloud-live-scores')
    table.put_item(Item={
        'game_id': game_id,
        'home_team': home,
        'away_team': away,
        'home_score': home_score,
        'away_score': away_score,
        'quarter': quarter,
        'status': 'live' if quarter < 4 else 'final',
        'updated_at': datetime.utcnow().isoformat(),
        'expires_at': int(time.time()) + (3 * 60 * 60),
    })
    print(f"Updated: {home} {home_score}-{away_score} {away} (Q{quarter})")

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--game-id', required=True)
    p.add_argument('--home', required=True)
    p.add_argument('--away', required=True)
    p.add_argument('--home-score', type=int, required=True)
    p.add_argument('--away-score', type=int, required=True)
    p.add_argument('--quarter', type=int, required=True)
    args = p.parse_args()
    update_score(args.game_id, args.home, args.away,
                 args.home_score, args.away_score, args.quarter)
