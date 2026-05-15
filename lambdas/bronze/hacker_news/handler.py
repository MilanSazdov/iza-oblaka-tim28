import os


BRONZE_BUCKET = os.environ.get("BRONZE_BUCKET")


def lambda_handler(event, context):
    return {"items_written": 0, "s3_key": None}
