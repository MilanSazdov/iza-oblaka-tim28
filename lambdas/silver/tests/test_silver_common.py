import datetime as dt

import common


def test_clean_text_strips_html_and_unescapes():
    assert common.clean_text("<p>Hi &amp; bye</p>") == "Hi & bye"
    assert common.clean_text("<i>a</i>   b") == "a b"
    assert common.clean_text(None) is None
    assert common.clean_text("<p></p>") is None


def test_user_id_is_deterministic_and_platform_scoped():
    a = common.user_id("HackerNews", "alice")
    assert a == common.user_id("HackerNews", "alice")
    assert a != common.user_id("X", "alice")
    assert common.user_id("X", None) is None


def test_post_id_stable():
    assert common.post_id("alice", "2023-01-01", "hi") == common.post_id(
        "alice", "2023-01-01", "hi"
    )
    assert common.post_id("alice", "2023-01-01", "hi") != common.post_id(
        "bob", "2023-01-01", "hi"
    )


def test_epoch_to_utc():
    d = common.epoch_to_utc(1736978058)
    assert d.tzinfo == dt.timezone.utc
    assert d.year == 2025
    assert common.epoch_to_utc(None) is None


def test_to_bool():
    assert common.to_bool("True") is True
    assert common.to_bool("False") is False
    assert common.to_bool("1") is True
    assert common.to_bool(None) is None
    assert common.to_bool("maybe") is None
