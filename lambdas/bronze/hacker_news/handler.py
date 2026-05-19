import datetime as dt
import json
import logging
import os
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed

import boto3
import requests


HN_API = "https://hacker-news.firebaseio.com/v0"
BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]

ID_LISTS = ("topstories", "newstories", "beststories", "askstories",
            "jobstories", "showstories")

log = logging.getLogger()
log.setLevel(logging.INFO)

_s3 = boto3.client("s3")


def _target_day(event):
    if event and event.get("date"):
        return dt.date.fromisoformat(event["date"])
    return (dt.datetime.utcnow() - dt.timedelta(days=1)).date()


def _day_window(day):
    start = dt.datetime.combine(day, dt.time.min, tzinfo=dt.timezone.utc)
    end = start + dt.timedelta(days=1)
    return int(start.timestamp()), int(end.timestamp())


def _candidate_ids(session):
    out = set()
    for name in ID_LISTS:
        r = session.get(f"{HN_API}/{name}.json", timeout=15)
        r.raise_for_status()
        out.update(r.json() or [])
    return out


def _fetch_item(session, item_id):
    r = session.get(f"{HN_API}/item/{item_id}.json", timeout=15)
    r.raise_for_status()
    return r.json()


def _items_in_window(ids, lo, hi):
    keep = []
    with requests.Session() as s, ThreadPoolExecutor(max_workers=16) as pool:
        futures = {pool.submit(_fetch_item, s, i): i for i in ids}
        for f in as_completed(futures):
            item = f.result()
            if item and "time" in item and lo <= item["time"] < hi:
                keep.append(item)
    return keep


def _s3_key(day, run_id):
    return (
        f"source=hacker_news/year={day:%Y}/month={day:%m}/day={day:%d}/"
        f"items-{run_id}.json"
    )


def _put(items, key):
    body = "\n".join(json.dumps(i, separators=(",", ":")) for i in items)
    _s3.put_object(
        Bucket=BRONZE_BUCKET,
        Key=key,
        Body=body.encode("utf-8"),
        ContentType="application/x-ndjson",
    )


def lambda_handler(event, context):
    day = _target_day(event or {})
    lo, hi = _day_window(day)
    run_id = str(uuid.uuid4())[:8]
    log.info("hn ingest day=%s run=%s", day.isoformat(), run_id)

    with requests.Session() as s:
        ids = _candidate_ids(s)
    items = _items_in_window(ids, lo, hi)

    key = _s3_key(day, run_id)
    _put(items, key)
    log.info("wrote %d items to s3://%s/%s", len(items), BRONZE_BUCKET, key)

    return {
        "items_written": len(items),
        "s3_key": key,
        "bucket": BRONZE_BUCKET,
        "day": day.isoformat(),
    }
