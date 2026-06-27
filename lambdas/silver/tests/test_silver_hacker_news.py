import pandas as pd


def test_derive_type(hn):
    assert hn.derive_type(["story"], "A normal story") == "story"
    assert hn.derive_type(["story", "ask_hn"], "Ask HN: how?") == "ask"
    assert hn.derive_type(["story"], "Ask HN: lowercase match") == "ask"
    assert hn.derive_type(["comment", "author_x"], None) == "comment"
    assert hn.derive_type(["job"], None) == "job"
    assert hn.derive_type([], None) == "story"


def test_normalize_posts_users_relations(hn):
    items = [
        {
            "objectID": "1",
            "author": "bob",
            "created_at_i": 1736978100,
            "comment_text": "<i>hi there</i>",
            "_tags": ["comment"],
            "parent_id": 9,
            "story_id": 9,
        },
        {
            "objectID": "2",
            "author": "alice",
            "created_at_i": 1736978058,
            "title": "Ask HN: x?",
            "story_text": "<p>hello &amp; world</p>",
            "points": 10,
            "_tags": ["story", "ask_hn"],
        },
        # duplicate of objectID 2 -> must be deduped
        {
            "objectID": "2",
            "author": "alice",
            "created_at_i": 1736978058,
            "title": "Ask HN: x?",
            "_tags": ["story"],
            "points": 10,
        },
    ]
    posts, users, rel = hn.normalize(items)

    # posts deduped and sorted by datetime (alice 1736978058 before bob 1736978100)
    assert list(posts["id"]) == ["2", "1"]
    alice = posts[posts["id"] == "2"].iloc[0]
    assert alice["type"] == "ask"
    assert alice["text"] == "hello & world"
    assert alice["points"] == 10
    assert pd.isna(posts[posts["id"] == "1"].iloc[0]["points"])

    # users sorted lexicographically, follower/verified null for HN
    assert list(users["username"]) == ["alice", "bob"]
    assert users["user_followers"].isna().all()
    assert users["is_verified"].isna().all()

    # relations only for the comment
    assert list(rel["child_id"]) == ["1"]
    assert rel.iloc[0]["parent_id"] == "9"
    assert rel.iloc[0]["root_story_id"] == "9"
