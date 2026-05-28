#!/usr/bin/env python3
import boto3, json, logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ENVIRONMENTS_TO_MANAGE = ['dev', 'staging']

def get_instances_to_manage(ec2):
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'instance-state-name', 'Values': ['running', 'stopped']},
            {'Name': 'tag:Environment',     'Values': ENVIRONMENTS_TO_MANAGE},
        ]
    )
    instances = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instances.append({
                'id': instance['InstanceId'],
                'state': instance['State']['Name']
            })
    return instances

def lambda_handler(event, context):
    action = event.get('action', 'stop')
    ec2 = boto3.client('ec2', region_name='us-east-1')
    instances = get_instances_to_manage(ec2)

    if not instances:
        logger.info("No instances to manage")
        return {'action': action, 'instances': [], 'count': 0}

    if action == 'stop':
        running = [i['id'] for i in instances if i['state'] == 'running']
        if running:
            ec2.stop_instances(InstanceIds=running)
            logger.info(json.dumps({'event': 'instances_stopped', 'count': len(running), 'ids': running}))
        return {'action': action, 'instances': running, 'count': len(running)}
    elif action == 'start':
        stopped = [i['id'] for i in instances if i['state'] == 'stopped']
        if stopped:
            ec2.start_instances(InstanceIds=stopped)
            logger.info(json.dumps({'event': 'instances_started', 'count': len(stopped), 'ids': stopped}))
        return {'action': action, 'instances': stopped, 'count': len(stopped)}

    return {'action': action, 'instances': [], 'count': 0}
