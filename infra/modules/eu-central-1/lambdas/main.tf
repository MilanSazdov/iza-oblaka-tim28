# aws_lambda_function resources and CloudWatch Crons
#
# What goes here:
# - data "archive_file" to zip lambdas/bronze/hacker_news and lambdas/bronze/twitter
# - aws_lambda_function "hacker_news" (runtime python3.x, handler = handler.lambda_handler,
#     role = var.lambda_role_arn, vpc_config = { subnet_ids, security_group_ids })
# - aws_lambda_function "twitter" (same shape)
# - aws_cloudwatch_event_rule "schedule" with rate(...) for each lambda
# - aws_cloudwatch_event_target wiring rule -> lambda
# - aws_lambda_permission allowing EventBridge to invoke each lambda

locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_lambda_function" "hacker_news" {
  function_name = "${local.prefix}-bronze-hacker-news"
  role          = var.lambda_execution_role_arn

  runtime = "python3.11"
  handler = "handler.lambda_handler" # matches lambdas/bronze/hacker_news/handler.py

  filename         = var.hacker_news_zip_path
  source_code_hash = filebase64sha256(var.hacker_news_zip_path)

  environment {
    variables = {
      BRONZE_BUCKET = var.bronze_bucket_name
    }
  }
}

variable "hacker_news_zip_path" {
  type        = string
  description = "Path to packaged hacker_news lambda zip"
}