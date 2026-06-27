import datetime as dt

import pandas as pd

DAY = dt.date(2026, 1, 15)


def _hn_posts():
    return pd.DataFrame(
        {
            "id": ["1", "2", "3", "4"],
            "author_username": ["a", "a", "b", "c"],
            "type": ["story", "comment", "ask", "job"],
            "points": pd.array([5, pd.NA, 3, 7], dtype="Int64"),
        }
    )


def test_hn_daily_metrics(gold):
    m = gold.hn_daily_metrics(_hn_posts(), DAY).iloc[0]
    assert m["date"] == "2026-01-15"
    assert m["platform"] == "HackerNews"
    assert m["total_users"] == 3
    assert m["stories"] == 1
    assert m["asks"] == 1
    assert m["comments"] == 1
    assert m["jobs"] == 1
    assert m["polls"] == 0


def test_x_daily_metrics(gold):
    posts = pd.DataFrame({"author_username": ["x", "y", "x"]})
    m = gold.x_daily_metrics(posts, DAY).iloc[0]
    assert m["total_users"] == 2
    assert m["posts_count"] == 3


def test_karma_ranking_high_and_low(gold):
    high = gold.karma_ranking(_hn_posts(), DAY, ascending=False)
    # a: 5 + 0, b: 3, c: 7  -> c(7), a(5), b(3)
    assert list(high["username"]) == ["c", "a", "b"]
    assert list(high["karma"]) == [7, 5, 3]
    assert list(high["rank"]) == [1, 2, 3]

    low = gold.karma_ranking(_hn_posts(), DAY, ascending=True)
    assert list(low["username"]) == ["b", "a", "c"]


def test_top_posts_filters_by_type(gold):
    jobs = gold.top_posts(_hn_posts(), DAY, "job")
    assert list(jobs["id"]) == ["4"]
    assert jobs.iloc[0]["points"] == 7
    stories = gold.top_posts(_hn_posts(), DAY, "story")
    assert list(stories["id"]) == ["1"]


def test_top_followers(gold):
    users = pd.DataFrame(
        {"username": ["a", "b", "c"], "user_followers": [10, 99, 50]}
    )
    top = gold.top_followers(users, DAY)
    assert list(top["username"]) == ["b", "c", "a"]
    assert list(top["rank"]) == [1, 2, 3]


def test_data_quality(gold):
    tables = {"t": pd.DataFrame({"x": [1, None], "y": [1, 2]})}
    dq = gold.data_quality(tables, DAY)
    t = dq[dq["table_name"] == "t"].iloc[0]
    assert t["total_rows"] == 2
    assert t["total_cells"] == 4
    assert t["non_null_cells"] == 3
    assert t["dq_score_pct"] == 75.0
    overall = dq[dq["table_name"] == "overall"].iloc[0]
    assert overall["dq_score_pct"] == 75.0
