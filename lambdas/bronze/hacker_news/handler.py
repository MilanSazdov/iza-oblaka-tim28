# Python code to fetch HN data
#
# What goes here:
# - def lambda_handler(event, context):
#     - call Hacker News API (https://hacker-news.firebaseio.com/v0/...)
#     - collect top/new stories
#     - write raw JSON to s3://<bronze-bucket>/hacker_news/<yyyy>/<mm>/<dd>/<hh>.json
#     - return summary (count, s3 key)
