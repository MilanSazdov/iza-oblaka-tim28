"""Shared pure helpers for the silver normalization lambdas."""
import datetime as dt
import html
import re
import uuid

# Fixed namespace so ids are stable across runs.
_NS = uuid.UUID("d3f5e8a2-1c4b-4f6a-9e2d-7b8c0a1f2e3d")

# require a tag name after '<' so bare comparisons in text (e.g. "5 < 10 > 3")
# are preserved while real HTML tags are stripped
_TAG_RE = re.compile(r"</?[a-zA-Z][^>]*>")
_WS_RE = re.compile(r"\s+")

PLATFORM_HN = "HackerNews"
PLATFORM_X = "X"


def clean_text(value):
    """Unescape entities, strip HTML tags, collapse whitespace."""
    if value is None:
        return None
    text = html.unescape(str(value))
    text = _TAG_RE.sub(" ", text)
    text = _WS_RE.sub(" ", text).strip()
    return text or None


def user_id(platform, username):
    """Stable, deterministic user id derived from platform + username."""
    if username is None:
        return None
    return str(uuid.uuid5(_NS, f"{platform}:{username}"))


def post_id(*parts):
    """Deterministic post id from parts (X tweets have no native id)."""
    key = "|".join("" if p is None else str(p) for p in parts)
    return str(uuid.uuid5(_NS, key))


def epoch_to_utc(epoch):
    """Unix epoch seconds -> timezone-aware UTC datetime."""
    if epoch is None:
        return None
    return dt.datetime.fromtimestamp(int(epoch), tz=dt.timezone.utc)


def to_bool(value):
    """Parse a CSV-style boolean ('True'/'False'/'1'/...) into a bool/None."""
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    s = str(value).strip().lower()
    if s in ("true", "1", "t", "yes", "y"):
        return True
    if s in ("false", "0", "f", "no", "n"):
        return False
    return None


def partition_cols(series_utc):
    """Return (year, month, day) string columns from a UTC datetime series."""
    return (
        series_utc.dt.strftime("%Y"),
        series_utc.dt.strftime("%m"),
        series_utc.dt.strftime("%d"),
    )
