import logging
import os


BRONZE_BUCKET = os.environ.get("BRONZE_BUCKET")
DATASET_URL = os.environ.get("DATASET_URL")
DATASET_NAME = os.environ.get("DATASET_NAME", "tweets")

log = logging.getLogger()
log.setLevel(logging.INFO)


def lambda_handler(event, context):
    return {"dataset": DATASET_NAME, "items_written": 0, "s3_key": None}
