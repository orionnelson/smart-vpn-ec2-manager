#!/bin/bash

INSTANCE_IDS=$1
AWS_REGION=$2
RULE_NAME=$3

echo "import boto3" > index.py
echo "" >> index.py
echo "region = '$AWS_REGION'" >> index.py
echo "ec2 = boto3.client('ec2', region_name=region)" >> index.py
echo "events_client = boto3.client('events', region_name=region)" >> index.py
echo "" >> index.py
echo "INSTANCE_ID = '$INSTANCE_IDS'" >> index.py
echo "RULE_NAME = '$RULE_NAME'" >> index.py
echo "" >> index.py
echo "def handler(event, context):" >> index.py
echo "    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])" >> index.py
echo "    state = response['Reservations'][0]['Instances'][0]['State']['Name']" >> index.py
echo "    if 'source' in event and event['source'] == 'aws.events':" >> index.py
echo "        ec2.stop_instances(InstanceIds=[INSTANCE_ID])" >> index.py
echo "        print(f'Stopped instance: {INSTANCE_ID}')" >> index.py
echo "        return 'Function executed: Stopped instance'" >> index.py
echo "    elif state == 'stopped':" >> index.py
echo "        ec2.start_instances(InstanceIds=[INSTANCE_ID])" >> index.py
echo "        events_client.enable_rule(Name=RULE_NAME)" >> index.py
echo "        print(f'Started instance: {INSTANCE_ID}')" >> index.py
echo "        return 'Function executed: Started instance'" >> index.py
echo "    elif state == 'running':" >> index.py
echo "        events_client.disable_rule(Name=RULE_NAME)" >> index.py
echo "        events_client.enable_rule(Name=RULE_NAME)" >> index.py
echo "        print(f'Reset 30-minute countdown for instance: {INSTANCE_ID}')" >> index.py
echo "        return 'Function executed: Reset 30-minute countdown'" >> index.py
echo "    else:" >> index.py
echo "        print(f'Instance {INSTANCE_ID} is in {state} state.')" >> index.py
echo "        return f'Function executed: Instance is in {state} state'" >> index.py
zip lambda_function_payload.zip index.py