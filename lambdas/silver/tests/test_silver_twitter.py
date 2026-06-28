import pandas as pd


def test_normalize_dedup_union_sort(tw):
    raw = pd.DataFrame(
        {
            "user_name": ["bob", "alice", "alice"],
            "user_followers": [200, 100, 150],
            "date": [
                "2023-03-02 00:00:00",
                "2023-03-01 23:59:59",
                "2023-03-01 23:59:59",
            ],
            "text": ["yo", "hi <b>x</b>", "hi <b>x</b>"],
            "is_retweet": ["True", "False", "False"],
        }
    )
    posts, users = tw.normalize(raw)

    # the two identical alice rows collapse to one; sorted by datetime
    assert len(posts) == 2
    assert list(posts["author_username"]) == ["alice", "bob"]
    assert list(posts["type"]) == ["tweet", "retweet"]
    assert posts.iloc[0]["text"] == "hi x"
    assert posts["points"].isna().all()

    # users: alice keeps the max follower count, sorted lexicographically
    assert list(users["username"]) == ["alice", "bob"]
    alice = users[users["username"] == "alice"].iloc[0]
    assert alice["user_followers"] == 150
    bob = users[users["username"] == "bob"].iloc[0]
    assert bob["user_followers"] == 200
    assert "is_verified" not in users.columns


def test_normalize_tolerates_missing_columns(tw):
    raw = pd.DataFrame({"user_name": ["a"], "date": ["2023-03-01 12:00:00"], "text": ["hi"]})
    posts, users = tw.normalize(raw)
    assert len(posts) == 1
    assert posts.iloc[0]["type"] == "tweet"
    assert len(users) == 1
