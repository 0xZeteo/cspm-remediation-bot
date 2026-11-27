import json, boto3, os
from datetime import datetime
from urllib.parse import parse_qs

s3 = boto3.client('s3')

def lambda_handler(event, context):
    body = event['body']
    if event.get('isBase64Encoded'):
        import base64
        body = base64.b64decode(body).decode()

    parsed = parse_qs(body)
    payload = json.loads(parsed['payload'][0])
    action = json.loads(payload['actions'][0]['value'])

    if action['action'] == 'ignore':
        return {"statusCode": 200, "body": "Ignored"}

    resource = action['resource']
    bucket = resource.split(':')[-1]

    if os.environ.get('DRY_RUN', '').lower() == 'true':
        result = f"DRY RUN: would block public access on {bucket}"
    else:
        s3.put_public_access_block(
            Bucket=bucket,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
        result = f"Blocked public access on {bucket}"

    s3.put_object(
        Bucket=os.environ['AUDIT_BUCKET'],
        Key=f"remediations/{datetime.utcnow().isoformat()}-{bucket}.json",
        Body=json.dumps({"action": action, "result": result, "timestamp": datetime.utcnow().isoformat()})
    )

    return {"statusCode": 200, "body": result}
