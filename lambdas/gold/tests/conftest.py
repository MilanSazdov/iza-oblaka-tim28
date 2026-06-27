import importlib.util
import os
import sys
from pathlib import Path

import pytest

GOLD = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GOLD))

os.environ.setdefault("SILVER_BUCKET", "test-silver")
os.environ.setdefault("GOLD_BUCKET", "test-gold")
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")


@pytest.fixture(scope="session")
def gold():
    spec = importlib.util.spec_from_file_location(
        "gold_metrics_handler", GOLD / "metrics" / "handler.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
