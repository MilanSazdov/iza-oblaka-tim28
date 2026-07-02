import json
import logging
import os
import time

import requests


WEBHOOK_URL = os.environ["DISCORD_WEBHOOK_URL"]
_MAX_ATTEMPTS = 4  # retry transient Discord failures before giving up

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


def _post_with_retry(payload):
    """POST to Discord, retrying transient failures; raise on final failure so SNS retries."""
    for attempt in range(1, _MAX_ATTEMPTS + 1):
        try:
            r = requests.post(WEBHOOK_URL, json=payload, timeout=10)
            if r.status_code == 429 or r.status_code >= 500:
                raise requests.HTTPError(f"transient {r.status_code}")
            r.raise_for_status()
            return
        except requests.RequestException as e:
            if attempt == _MAX_ATTEMPTS:
                log.error("discord delivery failed after %d attempts: %s", attempt, e)
                raise
            backoff = 2 ** (attempt - 1)
            log.warning("discord post attempt %d failed (%s), retry in %ds", attempt, e, backoff)
            time.sleep(backoff)


def lambda_handler(event, context):
    sent = 0
    for record in event.get("Records", []):
        _post_with_retry(_format(record))
        sent += 1
    log.info("forwarded %d sns records to discord", sent)
    return {"forwarded": sent}
