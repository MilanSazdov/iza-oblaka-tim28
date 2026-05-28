import importlib

import responses


@responses.activate
def test_writes_dataset_to_partitioned_key(s3, monkeypatch):
    monkeypatch.setenv("DATASET_URL", "https://example.test/tweets.csv")
    monkeypatch.setenv("DATASET_NAME", "bitcoin-tweets")

    csv_body = b"id,text\n1,hello\n2,world\n"
    responses.add(
        responses.GET, "https://example.test/tweets.csv",
        body=csv_body, status=200,
        headers={"Content-Type": "text/csv"},
    )

    handler = importlib.import_module("lambdas.bronze.twitter.handler")
    importlib.reload(handler)

    result = handler.lambda_handler({"date": "2026-05-14"}, context=None)

    assert result["skipped"] is False
    assert result["s3_key"] == (
        "source=twitter/dataset=bitcoin-tweets/"
        "ingested_at=2026-05-14/data.csv"
    )
    body = s3.get_object(Bucket="test-bronze", Key=result["s3_key"])["Body"].read()
    assert body == csv_body


@responses.activate
def test_skip_when_object_exists(s3, monkeypatch):
    monkeypatch.setenv("DATASET_URL", "https://example.test/tweets.csv")
    monkeypatch.setenv("DATASET_NAME", "bitcoin-tweets")

    handler = importlib.import_module("lambdas.bronze.twitter.handler")
    importlib.reload(handler)

    key = "source=twitter/dataset=bitcoin-tweets/ingested_at=2026-05-14/data.csv"
    s3.put_object(Bucket="test-bronze", Key=key, Body=b"already there")

    result = handler.lambda_handler({"date": "2026-05-14"}, context=None)

    assert result["skipped"] is True
    assert result["s3_key"] == key
