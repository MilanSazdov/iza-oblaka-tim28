import sys
from pathlib import Path

import boto3
import pytest
from moto import mock_aws

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

BUCKET = "test-bronze"


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setenv("BRONZE_BUCKET", BUCKET)
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-central-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "test")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "test")


@pytest.fixture
def s3():
    with mock_aws():
        client = boto3.client("s3", region_name="eu-central-1")
        client.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-central-1"},
        )
        yield client
