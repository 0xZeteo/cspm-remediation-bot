import json, os, urllib.request

def lambda_handler(event, context):
    findings = event['detail']['findings']
    for finding in findings:
        title = finding['Title']
        severity = finding['Severity']['Label']
        resource = finding['Resources'][0]['Id']
        finding_id = finding['Id']

        message = {
            "text": f"🚨 {severity}: {title}",
            "blocks": [
                {"type": "section", "text": {"type": "mrkdwn",
                 "text": f"*{title}*\nSeverity: {severity}\nResource: `{resource}`"}},
                {"type": "actions", "elements": [
                    {"type": "button", "text": {"type": "plain_text", "text": "Fix"},
                     "style": "primary",
                     "value": json.dumps({"finding_id": finding_id, "resource": resource, "action": "fix"})},
                    {"type": "button", "text": {"type": "plain_text", "text": "Ignore"},
                     "value": json.dumps({"finding_id": finding_id, "action": "ignore"})}
                ]}
            ]
        }

        req = urllib.request.Request(
            os.environ['SLACK_WEBHOOK_URL'],
            data=json.dumps(message).encode(),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)
