"""Silver normalization for X: process one bronze twitter CSV (the just-uploaded
one, or the most recent) into posts/users parquet. Processing a single file per
run keeps a large multi-file dataset out of memory."""
import logging
import os

import boto3
import pandas as pd

import common

BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]
SILVER_BUCKET = os.environ["SILVER_BUCKET"]

log = logging.getLogger()
log.setLevel(logging.INFO)

_s3 = boto3.client("s3")


def normalize(raw):
    """Build posts / users dataframes from a raw Bitcoin-Tweets dataframe."""
    df = raw.copy()
    # Tolerate datasets that omit optional columns.
    for col in ("user_name", "user_followers", "date", "text", "is_retweet"):
        if col not in df.columns:
            df[col] = None

    datetime = pd.to_datetime(df["date"], utc=True, errors="coerce")
    df = df.assign(_dt=datetime)
    df = df[df["_dt"].notna() & df["user_name"].notna()]

    text = df["text"].map(common.clean_text)
    is_rt = df["is_retweet"].map(common.to_bool).fillna(False)

    posts = pd.DataFrame(
        {
            "id": [
                common.post_id(u, d.isoformat(), t)
                for u, d, t in zip(df["user_name"], df["_dt"], text)
            ],
            "author_username": df["user_name"].values,
            "datetime": df["_dt"].values,
            "points": pd.array([pd.NA] * len(df), dtype="Int64"),
            "type": ["retweet" if r else "tweet" for r in is_rt],
            "text": text.values,
        }
    )
    if not posts.empty:
        posts["datetime"] = pd.to_datetime(posts["datetime"], utc=True)
        posts = posts.drop_duplicates(subset="id").sort_values("datetime")

    followers = pd.to_numeric(df["user_followers"], errors="coerce")
    udf = pd.DataFrame(
        {
            "username": df["user_name"].values,
            "user_followers": followers.values,
        }
    )
    grouped = udf.groupby("username", as_index=False).agg(
        user_followers=("user_followers", "max")
    )
    users = pd.DataFrame(
        {
            "id": [common.user_id(common.PLATFORM_X, u) for u in grouped["username"]],
            "username": grouped["username"].values,
            "user_followers": grouped["user_followers"].astype("Int64").values,
        }
    ).sort_values("username")

    return posts, users


# only the columns the silver schema needs (keeps the large CSV out of memory)
_USECOLS = {"user_name", "user_followers", "date", "text", "is_retweet"}


def _target_key(event):
    """The CSV to process: the just-uploaded one (S3 EventBridge event) if
    present, otherwise the most recently modified CSV under source=twitter/."""
    key = (((event or {}).get("detail") or {}).get("object") or {}).get("key")
    if key:
        return key
    latest = None
    paginator = _s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BRONZE_BUCKET, Prefix="source=twitter/"):
        for obj in page.get("Contents", []):
            if obj["Key"].endswith(".csv") and (
                latest is None or obj["LastModified"] > latest["LastModified"]
            ):
                latest = obj
    return latest["Key"] if latest else None


def _read_csv(wr, key):
    return wr.s3.read_csv(
        path=f"s3://{BRONZE_BUCKET}/{key}",
        dataset=False,
        usecols=lambda c: c in _USECOLS,
    )


def _write_posts(wr, posts):
    if posts.empty:
        return 0
    posts = posts.copy()
    posts["platform"] = common.PLATFORM_X
    posts["year"], posts["month"], posts["day"] = common.partition_cols(posts["datetime"])
    wr.s3.to_parquet(
        df=posts,
        path=f"s3://{SILVER_BUCKET}/posts/",
        dataset=True,
        partition_cols=["platform", "year", "month", "day"],
        mode="append",  # files accumulate; gold dedups by id
        index=False,
    )
    return len(posts)


def _write_users(wr, users):
    path = f"s3://{SILVER_BUCKET}/users/"
    existing = pd.DataFrame(columns=users.columns)
    try:
        existing = wr.s3.read_parquet(
            path=f"{path}platform={common.PLATFORM_X}/", dataset=False
        )
    except Exception:  # no existing partition yet
        pass

    merged = pd.concat([existing, users], ignore_index=True)
    if "platform" in merged.columns:
        merged = merged.drop(columns=["platform"])
    # keep the largest follower count seen for each user; na_position="first"
    # ensures a real value (not NaN) survives drop_duplicates(keep="last")
    merged["user_followers"] = pd.to_numeric(merged["user_followers"], errors="coerce")
    merged = merged.sort_values("user_followers", na_position="first").drop_duplicates(
        subset="id", keep="last"
    )
    merged["user_followers"] = merged["user_followers"].astype("Int64")
    merged = merged.dropna(subset=["id"]).sort_values("username")
    merged["platform"] = common.PLATFORM_X
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

    key = _target_key(event or {})
    if not key:
        log.info("silver x: no twitter CSV found")
        return {"platform": common.PLATFORM_X, "file": None, "posts": 0, "users": 0}

    log.info("silver x reading %s", key)
    posts, users = normalize(_read_csv(wr, key))
    n_posts = _write_posts(wr, posts)
    n_users = _write_users(wr, users)

    log.info("silver x file=%s posts=%d users=%d", key, n_posts, n_users)
    return {"platform": common.PLATFORM_X, "file": key, "posts": n_posts, "users": n_users}
