"""Shared gold helpers: parquet IO + pure metric/KPI builders.

Pure builders take/return dataframes so they can be unit tested without
awswrangler.
"""
import pandas as pd

PLATFORM_HN = "HackerNews"
PLATFORM_X = "X"
TOP_N = 10


def read(wr, path, dataset=False):
    try:
        return wr.s3.read_parquet(path=path, dataset=dataset)
    except Exception:  # missing partition -> empty frame
        return pd.DataFrame()


def write(wr, df, gold_bucket, table, partition_cols):
    if df.empty:
        return 0
    wr.s3.to_parquet(
        df=df,
        path=f"s3://{gold_bucket}/{table}/",
        dataset=True,
        partition_cols=partition_cols,
        mode="overwrite_partitions",
        index=False,
    )
    return len(df)


def day_part(day):
    return f"year={day:%Y}/month={day:%m}/day={day:%d}/"


# ---- HN metrics -----------------------------------------------------------


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
    return sub[cols]


# ---- X metrics ------------------------------------------------------------


def x_daily_metrics_by_date(posts_x):
    """One row per tweet date: distinct users + post count (whole dataset)."""
    cols = ["date", "platform", "total_users", "posts_count"]
    if posts_x.empty:
        return pd.DataFrame(columns=cols)
    df = posts_x.copy()
    df["date"] = pd.to_datetime(df["datetime"], utc=True).dt.strftime("%Y-%m-%d")
    grouped = df.groupby("date", as_index=False).agg(
        total_users=("author_username", "nunique"),
        posts_count=("id", "count"),
    )
    grouped["platform"] = PLATFORM_X
    return grouped[cols]


def top_followers(users_x, day):
    cols = ["date", "username", "user_followers", "rank"]
    if users_x.empty:
        return pd.DataFrame(columns=cols)
    sub = users_x.copy()
    sub["user_followers"] = pd.to_numeric(sub["user_followers"], errors="coerce").fillna(0)
    sub = sub.sort_values("user_followers", ascending=False).head(TOP_N).reset_index(drop=True)
    sub["user_followers"] = sub["user_followers"].astype("int64")
    sub.insert(0, "date", day.isoformat())
    sub["rank"] = sub.index + 1
    return sub[cols]


# ---- data quality KPI -----------------------------------------------------


def data_quality(tables, day, platform):
    """% of non-null cells per silver table (+ overall) for one platform."""
    rows = []
    tot_cells = tot_nonnull = tot_rows = 0
    for name, df in tables.items():
        data = df.drop(columns=["platform", "year", "month", "day"], errors="ignore")
        cells = int(data.shape[0] * data.shape[1])
        nonnull = int(data.notna().sum().sum())
        rows.append(
            {
                "date": day.isoformat(),
                "platform": platform,
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
            "platform": platform,
            "table_name": "overall",
            "total_rows": int(tot_rows),
            "total_cells": tot_cells,
            "non_null_cells": tot_nonnull,
            "dq_score_pct": round(100.0 * tot_nonnull / tot_cells, 2) if tot_cells else 0.0,
        }
    )
    return pd.DataFrame(rows)
