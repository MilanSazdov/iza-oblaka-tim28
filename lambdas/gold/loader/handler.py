"""Load gold metric tables from S3 into PostgreSQL for Superset.

Full reload each run (gold is small): read each gold table from S3 and replace
the matching Postgres table. Postgres password is read from SSM at runtime.
"""
import logging
import os

import boto3

GOLD_BUCKET = os.environ["GOLD_BUCKET"]
PG_HOST = os.environ["PG_HOST"]
PG_PORT = int(os.environ.get("PG_PORT", "5432"))
PG_DB = os.environ["PG_DB"]
PG_USER = os.environ["PG_USER"]
PG_PASSWORD_SSM = os.environ["PG_PASSWORD_SSM"]

# gold tables to mirror into Postgres (same names as the S3 prefixes)
TABLES = ["daily_platform_metrics", "top_10_rankings", "data_quality"]

log = logging.getLogger()
log.setLevel(logging.INFO)

_ssm = boto3.client("ssm")


def _pg_password():
    return _ssm.get_parameter(Name=PG_PASSWORD_SSM, WithDecryption=True)["Parameter"]["Value"]


def lambda_handler(event, context):
    import awswrangler as wr
    import pg8000

    # top-level pg8000.connect() returns the exact connection type that
    # awswrangler.postgresql.to_sql validates against
    con = pg8000.connect(
        user=PG_USER,
        host=PG_HOST,
        port=PG_PORT,
        database=PG_DB,
        password=_pg_password(),
    )
    loaded = {}
    try:
        for table in TABLES:
            df = wr.s3.read_parquet(
                path=f"s3://{GOLD_BUCKET}/{table}/", dataset=True
            ) if _exists(wr, f"s3://{GOLD_BUCKET}/{table}/") else None
            if df is None or df.empty:
                log.info("skip %s (no gold data)", table)
                loaded[table] = 0
                continue
            # `date` is a gold partition value, so it reads back as a string and
            # would land as TEXT; force it to a real DATE column for Superset.
            dtype = {"date": "DATE"} if "date" in df.columns else None
            wr.postgresql.to_sql(
                df=df,
                con=con,
                table=table,
                schema="public",
                mode="overwrite",
                index=False,
                dtype=dtype,
            )
            loaded[table] = len(df)
            log.info("loaded %s rows=%d", table, len(df))
        con.commit()
    finally:
        con.close()

    return {"loaded": loaded}


def _exists(wr, path):
    try:
        return len(wr.s3.list_objects(path)) > 0
    except Exception:  # noqa: BLE001
        return False
