from __future__ import annotations

import argparse
import importlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

TARGETS = {
    "hacker_news": "lambdas.bronze.hacker_news.handler",
    "twitter":     "lambdas.bronze.twitter.handler",
    "discord":     "lambdas.notifier.discord.handler",
}


def _load_dotenv():
    env_file = ROOT / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", choices=TARGETS)
    ap.add_argument("--event", default="{}")
    args = ap.parse_args()

    _load_dotenv()
    module = importlib.import_module(TARGETS[args.target])
    result = module.lambda_handler(json.loads(args.event), context=None)
    print(json.dumps(result, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
