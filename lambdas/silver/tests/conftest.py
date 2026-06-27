import importlib.util
import os
import sys
from pathlib import Path

import pytest

SILVER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SILVER))  # make `import common` resolve

os.environ.setdefault("BRONZE_BUCKET", "test-bronze")
os.environ.setdefault("SILVER_BUCKET", "test-silver")
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "test")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "test")


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, SILVER / relpath)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def hn():
    return _load("silver_hn_handler", "hacker_news/handler.py")


@pytest.fixture(scope="session")
def tw():
    return _load("silver_tw_handler", "twitter/handler.py")
