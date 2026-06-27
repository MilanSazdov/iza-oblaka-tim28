"""Silver normalization for Hacker News: bronze NDJSON -> posts/users/relations parquet."""
import datetime as dt
import json
import logging
import os

import boto3
import pandas as pd

import common

BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]
SILVER_BUCKET = os.environ["SILVER_BUCKET"]

# Canonical Hacker News item types, in priority order, as they appear in _tags.
_TYPE_TAGS = ("story", "comment", "poll", "pollopt", "job")

log = logging.getLogger()
log.setLevel(logging.INFO)

_s3 = boto3.client("s3")


def _target_day(event):
    if event and event.get("date"):
        return dt.date.fromisoformat(event["date"])
    return (dt.datetime.utcnow() - dt.timedelta(days=1)).date()


def _bronze_prefix(day):
    return f"source=hacker_news/year={day:%Y}/month={day:%m}/day={day:%d}/"


def _read_items(prefix):
    """Read every NDJSON object under the prefix into a list of dicts."""
    items = []
    paginator = _s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BRONZE_BUCKET, Prefix=prefix):
        for obj in page.get("Contents", []):
            body = _s3.get_object(Bucket=BRONZE_BUCKET, Key=obj["Key"])["Body"].read()
            for line in body.decode("utf-8").splitlines():
                line = line.strip()
                if line:
                    items.append(json.loads(line))
    return items


def derive_type(tags, title):
    """Map Algolia _tags + title to a single canonical post type."""
    tags = tags or []
    base = next((t for t in _TYPE_TAGS if t in tags), None)
    if base == "story":
        if "ask_hn" in tags or (title or "").lower().startswith("ask hn:"):
            return "ask"
    return base or "story"


def normalize(items):
    """Build the posts / users / relations dataframes from raw HN items."""
    posts, relations = [], []
    usernames = set()

    for it in items:
        oid = it.get("objectID")
        if oid is None:
            continue
        author = it.get("author")
        created = common.epoch_to_utc(it.get("created_at_i"))
        ptype = derive_type(it.get("_tags"), it.get("title"))
        text = common.clean_text(
            it.get("comment_text") or it.get("story_text") or it.get("title")
        )
        points = it.get("points")

        posts.append(
            {
                "id": str(oid),
                "author_username": author,
                "datetime": created,
                "points": points,
                "type": ptype,
                "text": text,
            }
        )
        if author:
            usernames.add(author)

        if it.get("parent_id") is not None:
            relations.append(
                {
                    "child_id": str(oid),
                    "parent_id": str(it.get("parent_id")),
                    "root_story_id": None
                    if it.get("story_id") is None
                    else str(it.get("story_id")),
                    "datetime": created,
                }
            )

    posts_df = pd.DataFrame(
        posts,
        columns=["id", "author_username", "datetime", "points", "type", "text"],
    )
    if not posts_df.empty:
        posts_df["datetime"] = pd.to_datetime(posts_df["datetime"], utc=True)
        posts_df["points"] = posts_df["points"].astype("Int64")
        posts_df = posts_df.drop_duplicates(subset="id").sort_values("datetime")

    users_df = pd.DataFrame(
        [
            {
                "id": common.user_id(common.PLATFORM_HN, u),
                "username": u,
                "user_followers": pd.NA,
                "is_verified": pd.NA,
            }
            for u in sorted(usernames)
        ],
        columns=["id", "username", "user_followers", "is_verified"],
    )

    relations_df = pd.DataFrame(
        relations, columns=["child_id", "parent_id", "root_story_id", "datetime"]
    )
    if not relations_df.empty:
        relations_df["datetime"] = pd.to_datetime(relations_df["datetime"], utc=True)
        relations_df = relations_df.drop_duplicates(subset="child_id")

    return posts_df, users_df, relations_df


def _write_dated(wr, df, table):
    if df.empty:
        return 0
    df = df.copy()
    df["platform"] = common.PLATFORM_HN
    df["year"], df["month"], df["day"] = common.partition_cols(df["datetime"])
    wr.s3.to_parquet(
        df=df,
        path=f"s3://{SILVER_BUCKET}/{table}/",
        dataset=True,
        partition_cols=["platform", "year", "month", "day"],
        mode="overwrite_partitions",
        index=False,
    )
    return len(df)


def _write_users(wr, users_df):
    """Upsert the users dimension: union with existing, dedup, sort, overwrite."""
    path = f"s3://{SILVER_BUCKET}/users/"
    existing = pd.DataFrame(columns=users_df.columns)
    try:
        existing = wr.s3.read_parquet(
            path=f"{path}platform={common.PLATFORM_HN}/", dataset=False
        )
    except Exception:  # no existing partition yet
        pass

    merged = pd.concat([existing, users_df], ignore_index=True)
    if "platform" in merged.columns:
        merged = merged.drop(columns=["platform"])
    merged = (
        merged.dropna(subset=["id"])
        .drop_duplicates(subset="id", keep="last")
        .sort_values("username")
    )
    merged["platform"] = common.PLATFORM_HN
    wr.s3.to_parquet(
        df=merged,
        path=path,
        dataset=True,
        partition_cols=["platform"],
        mode="overwrite_partitions",
        index=False,
    )
    return len(merged)


def lambda_handler(event, context):
    import awswrangler as wr

    day = _target_day(event or {})
    prefix = _bronze_prefix(day)
    log.info("silver hn day=%s prefix=%s", day.isoformat(), prefix)

    items = _read_items(prefix)
    posts_df, users_df, relations_df = normalize(items)

    n_posts = _write_dated(wr, posts_df, "posts")
    n_rel = _write_dated(wr, relations_df, "post_relations")
    n_users = _write_users(wr, users_df)

    log.info("silver hn posts=%d relations=%d users=%d", n_posts, n_rel, n_users)
    return {
        "platform": common.PLATFORM_HN,
        "day": day.isoformat(),
        "posts": n_posts,
        "relations": n_rel,
        "users": n_users,
    }
