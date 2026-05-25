import json
import logging
import os

import requests


WEBHOOK_URL = os.environ["DISCORD_WEBHOOK_URL"]

log = logging.getLogger()
log.setLevel(logging.INFO)


def _format(record):
    sns = record.get("Sns", {})
    subject = sns.get("Subject") or "AWS notification"
    message = sns.get("Message") or ""

    parsed = None
    try:
        parsed = json.loads(message)
    except (TypeError, ValueError):
        parsed = None

    if isinstance(parsed, dict) and "AlarmName" in parsed:
        title = f"ALARM {parsed['AlarmName']} {parsed.get('NewStateValue')}"
        body = parsed.get("NewStateReason") or message
    elif isinstance(parsed, dict) and "requestPayload" in parsed:
        rc = parsed.get("responseContext", {})
        title = f"Lambda async failure {rc.get('functionArn', '?')}"
        body = json.dumps(
            {"request": parsed.get("requestPayload"),
             "response": parsed.get("responsePayload")},
            indent=2,
        )[:1800]
    else:
        title = subject
        body = message[:1800]

    return {"username": "aws-alerts", "content": f"**{title}**\n```\n{body}\n```"}


def lambda_handler(event, context):
    sent = 0
    for record in event.get("Records", []):
        payload = _format(record)
        r = requests.post(WEBHOOK_URL, json=payload, timeout=10)
        r.raise_for_status()
        sent += 1
    log.info("forwarded %d sns records to discord", sent)
    return {"forwarded": sent}
