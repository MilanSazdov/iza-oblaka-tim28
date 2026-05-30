import datetime as dt
import importlib
import json
from urllib.parse import parse_qs, urlparse

import responses


def _epoch(day, hour=12):
    return int(dt.datetime(day.year, day.month, day.day, hour,
                           tzinfo=dt.timezone.utc).timestamp())


def _parse_window(url):
    qs = parse_qs(urlparse(url).query)
    nf = qs["numericFilters"][0]
    lo = int(nf.split("created_at_i>=")[1].split(",")[0])
    hi = int(nf.split("created_at_i<")[1])
    return lo, hi


@responses.activate
def test_writes_only_items_in_target_day(s3):
    target = dt.date(2026, 5, 14)
    target_epoch = _epoch(target, hour=12)

    in_window = {
        "objectID": "1",
        "created_at_i": target_epoch,
        "title": "in window",
        "_tags": ["story"],
    }
    a_comment = {
        "objectID": "2",
        "created_at_i": target_epoch + 60,
        "comment_text": "hello",
        "_tags": ["comment"],
    }

    def callback(req):
        lo, hi = _parse_window(req.url)
        hits = [h for h in (in_window, a_comment) if lo <= h["created_at_i"] < hi]
        body = {"hits": hits, "nbPages": 1, "page": 0, "hitsPerPage": 1000}
        return (200, {}, json.dumps(body))

    responses.add_callback(
        responses.GET,
        "https://hn.algolia.com/api/v1/search_by_date",
        callback=callback,
    )

    handler = importlib.import_module("lambdas.bronze.hacker_news.handler")
    importlib.reload(handler)

    result = handler.lambda_handler({"date": target.isoformat()}, context=None)

    assert result["items_written"] == 2
    obj = s3.get_object(Bucket="test-bronze", Key=result["s3_key"])
    lines = obj["Body"].read().decode().strip().splitlines()
    written = [json.loads(line) for line in lines]
    assert sorted(it["objectID"] for it in written) == ["1", "2"]
    assert result["s3_key"].startswith("source=hacker_news/year=2026/month=05/day=14/")

    first_qs = parse_qs(urlparse(responses.calls[0].request.url).query)
    assert first_qs["tags"][0] == "(story,comment,poll,pollopt,job)"
