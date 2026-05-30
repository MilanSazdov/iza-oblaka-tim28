import datetime as dt
import json
import logging
import os
import uuid

import boto3
import requests


ALGOLIA_API = "https://hn.algolia.com/api/v1/search_by_date"
BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]

TAGS = "(story,comment,poll,pollopt,job)"
HITS_PER_PAGE = 1000
SLICE_SECONDS = 1800

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


def _fetch_slice(session, lo, hi):
    items = []
    page = 0
    while True:
        params = {
            "tags": TAGS,
            "numericFilters": f"created_at_i>={lo},created_at_i<{hi}",
            "hitsPerPage": HITS_PER_PAGE,
            "page": page,
        }
        r = session.get(ALGOLIA_API, params=params, timeout=30)
        r.raise_for_status()
        body = r.json()
        hits = body.get("hits", [])
        items.extend(hits)
        nb_pages = body.get("nbPages", 0)
        if page + 1 >= nb_pages or not hits:
            if len(items) >= HITS_PER_PAGE * max(nb_pages, 1):
                log.warning("slice %s-%s hit pagination ceiling (%d)",
                            lo, hi, len(items))
            return items
        page += 1


def _collect_items(lo, hi):
    out = []
    with requests.Session() as s:
        cur = lo
        while cur < hi:
            nxt = min(cur + SLICE_SECONDS, hi)
            out.extend(_fetch_slice(s, cur, nxt))
            cur = nxt
    return out


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

    items = _collect_items(lo, hi)

    key = _s3_key(day, run_id)
    _put(items, key)
    log.info("wrote %d items to s3://%s/%s", len(items), BRONZE_BUCKET, key)

    return {
        "items_written": len(items),
        "s3_key": key,
        "bucket": BRONZE_BUCKET,
        "day": day.isoformat(),
    }
