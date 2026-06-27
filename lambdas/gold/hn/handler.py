"""Gold HN: per-day Hacker News metrics, top-10 rankings and DQ.

Runs in the daily state machine after silver-hacker-news. Backfillable by
passing {"date": "YYYY-MM-DD"}.
"""
import datetime as dt
import logging
import os

import goldlib as g

SILVER_BUCKET = os.environ["SILVER_BUCKET"]
GOLD_BUCKET = os.environ["GOLD_BUCKET"]

log = logging.getLogger()
log.setLevel(logging.INFO)


def _target_day(event):
    if event and event.get("date"):
        return dt.date.fromisoformat(event["date"])
    return (dt.datetime.utcnow() - dt.timedelta(days=1)).date()


def lambda_handler(event, context):
    import awswrangler as wr

    day = _target_day(event or {})
    part = g.day_part(day)
    sp = f"s3://{SILVER_BUCKET}"
    log.info("gold hn day=%s", day.isoformat())

    posts = g.read(wr, f"{sp}/posts/platform={g.PLATFORM_HN}/{part}")
    users = g.read(wr, f"{sp}/users/platform={g.PLATFORM_HN}/")
    relations = g.read(wr, f"{sp}/post_relations/platform={g.PLATFORM_HN}/{part}")

    g.write(wr, g.hn_daily_metrics(posts, day), GOLD_BUCKET,
            "daily_platform_metrics", ["platform", "date"])

    rankings = {
        "hn_highest_karma": g.karma_ranking(posts, day, ascending=False),
        "hn_lowest_karma": g.karma_ranking(posts, day, ascending=True),
        "hn_top_jobs": g.top_posts(posts, day, "job"),
        "hn_top_stories": g.top_posts(posts, day, "story"),
    }
    for metric, df in rankings.items():
        if not df.empty:
            g.write(wr, df.assign(metric=metric), GOLD_BUCKET,
                    "top_10_rankings", ["metric", "date"])

    dq = g.data_quality(
        {"posts_hn": posts, "users_hn": users, "relations_hn": relations},
        day, g.PLATFORM_HN,
    )
    g.write(wr, dq, GOLD_BUCKET, "data_quality", ["platform", "date"])

    log.info("gold hn done posts=%d", len(posts))
    return {"day": day.isoformat(), "platform": g.PLATFORM_HN, "posts": int(len(posts))}
