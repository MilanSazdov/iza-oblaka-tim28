import datetime as dt
import logging
import os

import boto3
import botocore.exceptions
import requests


BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]
DATASET_URL = os.environ["DATASET_URL"]
DATASET_NAME = os.environ.get("DATASET_NAME", "tweets")

log = logging.getLogger()
log.setLevel(logging.INFO)

_s3 = boto3.client("s3")


def _ingest_day(event):
    if event and event.get("date"):
        return dt.date.fromisoformat(event["date"])
    return dt.datetime.utcnow().date()


def _s3_key(day):
    return (
        f"source=twitter/dataset={DATASET_NAME}/"
        f"ingested_at={day.isoformat()}/data.csv"
    )


def _exists(key):
    try:
        _s3.head_object(Bucket=BRONZE_BUCKET, Key=key)
        return True
    except botocore.exceptions.ClientError as e:
        if e.response["Error"]["Code"] in ("404", "NoSuchKey", "NotFound"):
            return False
        raise


def lambda_handler(event, context):
    day = _ingest_day(event or {})
    key = _s3_key(day)

    if _exists(key):
        log.info("twitter ingest skip, object exists at s3://%s/%s", BRONZE_BUCKET, key)
        return {"dataset": DATASET_NAME, "s3_key": key, "skipped": True}

    log.info("twitter ingest download %s", DATASET_URL)
    with requests.get(DATASET_URL, stream=True, timeout=60) as r:
        r.raise_for_status()
        _s3.put_object(
            Bucket=BRONZE_BUCKET,
            Key=key,
            Body=r.content,
            ContentType="text/csv",
        )

    log.info("twitter wrote s3://%s/%s", BRONZE_BUCKET, key)
    return {
        "dataset": DATASET_NAME,
        "s3_key": key,
        "bucket": BRONZE_BUCKET,
        "skipped": False,
    }
