"""Gold X: batch recompute of all X metrics over the whole silver dataset.

Runs after silver-twitter (a new CSV upload), since the X dataset is static and
only changes when reuploaded. Produces per-date X user counts, the top-10
followers snapshot, and the X data-quality KPI.
"""
import datetime as dt
import logging
import os

import pandas as pd

import goldlib as g

SILVER_BUCKET = os.environ["SILVER_BUCKET"]
GOLD_BUCKET = os.environ["GOLD_BUCKET"]

log = logging.getLogger()
log.setLevel(logging.INFO)


def lambda_handler(event, context):
    import awswrangler as wr

    sp = f"s3://{SILVER_BUCKET}"
    log.info("gold x batch")

    posts = g.read(wr, f"{sp}/posts/platform={g.PLATFORM_X}/", dataset=True)
    users = g.read(wr, f"{sp}/users/platform={g.PLATFORM_X}/")

    # snapshot date for the followers ranking + DQ = latest tweet date present
    if not posts.empty:
        snapshot = pd.to_datetime(posts["datetime"], utc=True).max().date()
    else:
        snapshot = dt.datetime.utcnow().date()

    n_daily = g.write(wr, g.x_daily_metrics_by_date(posts), GOLD_BUCKET,
                      "daily_platform_metrics", ["platform", "date"])

    followers = g.top_followers(users, snapshot)
    if not followers.empty:
        g.write(wr, followers.assign(metric="x_most_followers"), GOLD_BUCKET,
                "top_10_rankings", ["metric", "date"])

    dq = g.data_quality({"posts_x": posts, "users_x": users}, snapshot, g.PLATFORM_X)
    g.write(wr, dq, GOLD_BUCKET, "data_quality", ["platform", "date"])

    log.info("gold x done posts=%d dates=%d", len(posts), n_daily)
    return {"platform": g.PLATFORM_X, "posts": int(len(posts)), "dates": int(n_daily)}
