import os
import sys
from pathlib import Path

import pytest

GOLD = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GOLD))  # make `import goldlib` resolve

os.environ.setdefault("SILVER_BUCKET", "test-silver")
os.environ.setdefault("GOLD_BUCKET", "test-gold")
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")


@pytest.fixture(scope="session")
def g():
    import goldlib

    return goldlib
