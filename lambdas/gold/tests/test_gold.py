import datetime as dt

import pandas as pd

DAY = dt.date(2026, 1, 15)


def _hn_posts():
    return pd.DataFrame(
        {
            "id": ["1", "2", "3", "4"],
            "author_username": ["a", "a", "b", "c"],
            "type": ["story", "comment", "ask", "job"],
            "text": ["t1", "t2", "t3", "t4"],
            "points": pd.array([5, pd.NA, 3, 7], dtype="Int64"),
        }
    )


def test_hn_daily_metrics(g):
    m = g.hn_daily_metrics(_hn_posts(), DAY).iloc[0]
    assert m["platform"] == "HackerNews"
    assert m["total_users"] == 3
    assert m["stories"] == 1
    assert m["asks"] == 1
    assert m["comments"] == 1
    assert m["jobs"] == 1
    assert m["polls"] == 0


def test_karma_ranking(g):
    high = g.karma_ranking(_hn_posts(), DAY, ascending=False)
    assert list(high["username"]) == ["c", "a", "b"]
    assert list(high["karma"]) == [7, 5, 3]
    low = g.karma_ranking(_hn_posts(), DAY, ascending=True)
    assert list(low["username"]) == ["b", "a", "c"]


def test_top_posts(g):
    assert list(g.top_posts(_hn_posts(), DAY, "job")["id"]) == ["4"]
    assert list(g.top_posts(_hn_posts(), DAY, "story")["id"]) == ["1"]


def test_x_daily_metrics_by_date(g):
    posts = pd.DataFrame(
        {
            "id": ["1", "2", "3"],
            "author_username": ["x", "y", "x"],
            "datetime": pd.to_datetime(
                ["2023-03-01 10:00", "2023-03-01 11:00", "2023-03-02 09:00"], utc=True
            ),
        }
    )
    m = g.x_daily_metrics_by_date(posts).set_index("date")
    assert m.loc["2023-03-01", "total_users"] == 2
    assert m.loc["2023-03-01", "posts_count"] == 2
    assert m.loc["2023-03-02", "total_users"] == 1
    assert (m["platform"] == "X").all()


def test_top_followers(g):
    users = pd.DataFrame({"username": ["a", "b", "c"], "user_followers": [10, 99, 50]})
    top = g.top_followers(users, DAY)
    assert list(top["username"]) == ["b", "c", "a"]
    assert list(top["rank"]) == [1, 2, 3]


def test_data_quality_has_platform(g):
    tables = {"t": pd.DataFrame({"x": [1, None], "y": [1, 2]})}
    dq = g.data_quality(tables, DAY, "HackerNews")
    t = dq[dq["table_name"] == "t"].iloc[0]
    assert t["platform"] == "HackerNews"
    assert t["dq_score_pct"] == 75.0
    assert (dq["table_name"] == "overall").any()
