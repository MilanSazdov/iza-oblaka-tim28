import datetime as dt
import importlib
import json

import responses


def _epoch(day, hour=12):
    return int(dt.datetime(day.year, day.month, day.day, hour,
                           tzinfo=dt.timezone.utc).timestamp())


@responses.activate
def test_writes_only_items_in_target_day(s3, monkeypatch):
    target = dt.date(2026, 5, 14)
    yesterday = target - dt.timedelta(days=1)

    for name in ("topstories", "newstories", "beststories",
                 "askstories", "jobstories", "showstories"):
        responses.add(
            responses.GET,
            f"https://hacker-news.firebaseio.com/v0/{name}.json",
            json=[1, 2], status=200,
        )

    responses.add(
        responses.GET,
        "https://hacker-news.firebaseio.com/v0/item/1.json",
        json={"id": 1, "time": _epoch(target), "type": "story"},
        status=200,
    )
    responses.add(
        responses.GET,
        "https://hacker-news.firebaseio.com/v0/item/2.json",
        json={"id": 2, "time": _epoch(yesterday), "type": "story"},
        status=200,
    )

    handler = importlib.import_module("lambdas.bronze.hacker_news.handler")
    importlib.reload(handler)

    result = handler.lambda_handler({"date": target.isoformat()}, context=None)

    assert result["items_written"] == 1
    obj = s3.get_object(Bucket="test-bronze", Key=result["s3_key"])
    lines = obj["Body"].read().decode().strip().splitlines()
    written = [json.loads(line) for line in lines]
    assert [it["id"] for it in written] == [1]
    assert result["s3_key"].startswith("source=hacker_news/year=2026/month=05/day=14/")
