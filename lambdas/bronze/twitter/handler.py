# Python code/scripts for X (Twitter) datasets
#
# What goes here:
# - def lambda_handler(event, context):
#     - authenticate to X / Twitter API (bearer token from env var or AWS Secrets Manager)
#     - fetch tweets / search results relevant to the project
#     - write raw JSON to s3://<bronze-bucket>/twitter/<yyyy>/<mm>/<dd>/<hh>.json
#     - return summary (count, s3 key)
