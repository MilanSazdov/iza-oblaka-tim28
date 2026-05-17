import datetime as dt
import logging
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Iterable

import requests


HN_API = "https://hacker-news.firebaseio.com/v0"
BRONZE_BUCKET = os.environ.get("BRONZE_BUCKET")

ID_LISTS = ("topstories", "newstories", "beststories", "askstories",
            "jobstories", "showstories")

log = logging.getLogger()
log.setLevel(logging.INFO)


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
        ids = r.json() or []
        out.update(ids)
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


def lambda_handler(event, context):
    day = _target_day(event or {})
    lo, hi = _day_window(day)
    log.info("hn ingest day=%s window=[%d, %d)", day.isoformat(), lo, hi)

    with requests.Session() as s:
        candidates = _candidate_ids(s)

    items = _items_in_window(candidates, lo, hi)
    log.info("hn items in window: %d", len(items))

    return {"items_written": len(items), "s3_key": None, "day": day.isoformat()}
