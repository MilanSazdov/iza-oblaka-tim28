"""Gold: silver parquet -> daily metrics, top-10 rankings, data-quality KPI."""
import datetime as dt
import logging
import os

import pandas as pd

SILVER_BUCKET = os.environ["SILVER_BUCKET"]
GOLD_BUCKET = os.environ["GOLD_BUCKET"]

PLATFORM_HN = "HackerNews"
PLATFORM_X = "X"
TOP_N = 10

log = logging.getLogger()
log.setLevel(logging.INFO)


def _target_day(event):
    if event and event.get("date"):
        return dt.date.fromisoformat(event["date"])
    return (dt.datetime.utcnow() - dt.timedelta(days=1)).date()


def _read(wr, path):
    try:
        return wr.s3.read_parquet(path=path, dataset=False)
    except Exception:  # missing partition -> empty frame
        return pd.DataFrame()


def _day_part(day):
    return f"year={day:%Y}/month={day:%m}/day={day:%d}/"


def hn_daily_metrics(posts_hn, day):
    types = posts_hn["type"] if "type" in posts_hn.columns else pd.Series(dtype=str)
    return pd.DataFrame(
        [
            {
                "date": day.isoformat(),
                "platform": PLATFORM_HN,
                "total_users": posts_hn["author_username"].nunique()
                if not posts_hn.empty
                else 0,
                "stories": int((types == "story").sum()),
                "asks": int((types == "ask").sum()),
                "comments": int((types == "comment").sum()),
                "jobs": int((types == "job").sum()),
                "polls": int((types == "poll").sum()),
            }
        ]
    )


def x_daily_metrics(posts_x, day):
    return pd.DataFrame(
        [
            {
                "date": day.isoformat(),
                "platform": PLATFORM_X,
                "total_users": posts_x["author_username"].nunique()
                if not posts_x.empty
                else 0,
                "posts_count": int(len(posts_x)),
            }
        ]
    )


def karma_ranking(posts_hn, day, ascending):
    if posts_hn.empty:
        return pd.DataFrame(columns=["date", "username", "karma", "rank"])
    karma = (
        posts_hn.assign(points=pd.to_numeric(posts_hn["points"], errors="coerce").fillna(0))
        .groupby("author_username", as_index=False)["points"]
        .sum()
        .rename(columns={"author_username": "username", "points": "karma"})
        .sort_values("karma", ascending=ascending)
        .head(TOP_N)
        .reset_index(drop=True)
    )
    karma["karma"] = karma["karma"].astype("int64")
    karma.insert(0, "date", day.isoformat())
    karma["rank"] = karma.index + 1
    return karma


def top_posts(posts_hn, day, ptype):
    cols = ["date", "id", "author_username", "points", "text", "rank"]
    if posts_hn.empty:
        return pd.DataFrame(columns=cols)
    sub = posts_hn[posts_hn["type"] == ptype].copy()
    if "text" not in sub.columns:
        sub["text"] = None
    sub["points"] = pd.to_numeric(sub["points"], errors="coerce").fillna(0).astype("int64")
    sub = sub.sort_values("points", ascending=False).head(TOP_N).reset_index(drop=True)
    sub.insert(0, "date", day.isoformat())
    sub["rank"] = sub.index + 1
    return sub[["date", "id", "author_username", "points", "text", "rank"]]


def top_followers(users_x, day):
    cols = ["date", "username", "user_followers", "rank"]
    if users_x.empty:
        return pd.DataFrame(columns=cols)
    sub = users_x.copy()
    sub["user_followers"] = pd.to_numeric(sub["user_followers"], errors="coerce").fillna(0)
    sub = (
        sub.sort_values("user_followers", ascending=False)
        .head(TOP_N)
        .reset_index(drop=True)
    )
    sub["user_followers"] = sub["user_followers"].astype("int64")
    sub.insert(0, "date", day.isoformat())
    sub["rank"] = sub.index + 1
    return sub[cols]


def data_quality(tables, day):
    rows = []
    tot_cells = tot_nonnull = tot_rows = 0
    for name, df in tables.items():
        data = df.drop(columns=["platform", "year", "month", "day"], errors="ignore")
        cells = int(data.shape[0] * data.shape[1])
        nonnull = int(data.notna().sum().sum())
        rows.append(
            {
                "date": day.isoformat(),
                "table_name": name,
                "total_rows": int(len(df)),
                "total_cells": cells,
                "non_null_cells": nonnull,
                "dq_score_pct": round(100.0 * nonnull / cells, 2) if cells else 0.0,
            }
        )
        tot_cells += cells
        tot_nonnull += nonnull
        tot_rows += len(df)
    rows.append(
        {
            "date": day.isoformat(),
            "table_name": "overall",
            "total_rows": int(tot_rows),
            "total_cells": tot_cells,
            "non_null_cells": tot_nonnull,
            "dq_score_pct": round(100.0 * tot_nonnull / tot_cells, 2) if tot_cells else 0.0,
        }
    )
    return pd.DataFrame(rows)


def _write(wr, df, table, partition_cols):
    if df.empty:
        return 0
    wr.s3.to_parquet(
        df=df,
        path=f"s3://{GOLD_BUCKET}/{table}/",
        dataset=True,
        partition_cols=partition_cols,
        mode="overwrite_partitions",
        index=False,
    )
    return len(df)


def lambda_handler(event, context):
    import awswrangler as wr

    day = _target_day(event or {})
    part = _day_part(day)
    sp = f"s3://{SILVER_BUCKET}"
    log.info("gold metrics day=%s", day.isoformat())

    posts_hn = _read(wr, f"{sp}/posts/platform={PLATFORM_HN}/{part}")
    posts_x = _read(wr, f"{sp}/posts/platform={PLATFORM_X}/{part}")
    users_hn = _read(wr, f"{sp}/users/platform={PLATFORM_HN}/")
    users_x = _read(wr, f"{sp}/users/platform={PLATFORM_X}/")
    relations_hn = _read(wr, f"{sp}/post_relations/platform={PLATFORM_HN}/{part}")

    # per platform so each parquet carries only its own columns
    _write(wr, hn_daily_metrics(posts_hn, day), "daily_platform_metrics", ["platform", "date"])
    _write(wr, x_daily_metrics(posts_x, day), "daily_platform_metrics", ["platform", "date"])

    rankings = {
        "x_most_followers": top_followers(users_x, day),
        "hn_highest_karma": karma_ranking(posts_hn, day, ascending=False),
        "hn_lowest_karma": karma_ranking(posts_hn, day, ascending=True),
        "hn_top_jobs": top_posts(posts_hn, day, "job"),
        "hn_top_stories": top_posts(posts_hn, day, "story"),
    }
    for metric, df in rankings.items():
        if df.empty:
            continue
        _write(wr, df.assign(metric=metric), "top_10_rankings", ["metric", "date"])

    dq = data_quality(
        {
            "users_hn": users_hn,
            "users_x": users_x,
            "posts_hn": posts_hn,
            "posts_x": posts_x,
            "relations_hn": relations_hn,
        },
        day,
    )
    _write(wr, dq, "data_quality", ["date"])

    log.info(
        "gold metrics done hn_posts=%d x_posts=%d", len(posts_hn), len(posts_x)
    )
    return {"day": day.isoformat(), "hn_posts": int(len(posts_hn)), "x_posts": int(len(posts_x))}
