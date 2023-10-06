import boto3

region = 'us-east-1'
ec2 = boto3.client('ec2', region_name=region)
events_client = boto3.client('events', region_name=region)

INSTANCE_ID = 'i-0288ce35090f5f9f9'
RULE_NAME = 'StopEC2After30Min'

def handler(event, context):
    response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    state = response['Reservations'][0]['Instances'][0]['State']['Name']
    if 'source' in event and event['source'] == 'aws.events':
        ec2.stop_instances(InstanceIds=[INSTANCE_ID])
        print(f'Stopped instance: {INSTANCE_ID}')
        return 'Function executed: Stopped instance'
    elif state == 'stopped':
        ec2.start_instances(InstanceIds=[INSTANCE_ID])
        events_client.enable_rule(Name=RULE_NAME)
        print(f'Started instance: {INSTANCE_ID}')
        return 'Function executed: Started instance'
    elif state == 'running':
        events_client.disable_rule(Name=RULE_NAME)
        events_client.enable_rule(Name=RULE_NAME)
        print(f'Reset 30-minute countdown for instance: {INSTANCE_ID}')
        return 'Function executed: Reset 30-minute countdown'
    else:
        print(f'Instance {INSTANCE_ID} is in {state} state.')
        return f'Function executed: Instance is in {state} state'
