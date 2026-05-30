locals {
  prefix = "${var.project_name}-${var.environment}"
  functions = {
    hacker_news = aws_lambda_function.hacker_news
    twitter     = aws_lambda_function.twitter
  }
  scheduled_functions = {
    hacker_news = aws_lambda_function.hacker_news
  }
}

resource "aws_lambda_function" "hacker_news" {
  function_name = "${local.prefix}-bronze-hacker-news"
  role          = var.lambda_execution_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 300
  memory_size   = 512

  filename         = var.hacker_news_zip_path
  source_code_hash = filebase64sha256(var.hacker_news_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  tracing_config { mode = "Active" }

  environment {
    variables = {
      BRONZE_BUCKET = var.bronze_bucket_name
    }
  }
}

resource "aws_lambda_function" "twitter" {
  function_name = "${local.prefix}-bronze-twitter"
  role          = var.lambda_execution_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 300
  memory_size   = 512

  filename         = var.twitter_zip_path
  source_code_hash = filebase64sha256(var.twitter_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  tracing_config { mode = "Active" }

  environment {
    variables = {
      BRONZE_BUCKET = var.bronze_bucket_name
      DATASET_URL   = var.twitter_dataset_url
      DATASET_NAME  = var.twitter_dataset_name
    }
  }
}

resource "aws_cloudwatch_log_group" "bronze" {
  for_each          = local.functions
  name              = "/aws/lambda/${each.value.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_event_rule" "daily" {
  for_each            = local.scheduled_functions
  name                = "${each.value.function_name}-daily"
  description         = "Daily bronze ingest for ${each.key}"
  schedule_expression = "cron(0 2 * * ? *)"
}

resource "aws_cloudwatch_event_target" "daily" {
  for_each = local.scheduled_functions
  rule     = aws_cloudwatch_event_rule.daily[each.key].name
  arn      = each.value.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  for_each      = local.scheduled_functions
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily[each.key].arn
}

resource "aws_lambda_function_event_invoke_config" "bronze" {
  for_each      = local.functions
  function_name = each.value.function_name

  maximum_retry_attempts = 1

  destination_config {
    on_failure {
      destination = var.alerts_sns_topic_arn
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  for_each = local.functions

  alarm_name          = "${each.value.function_name}-errors"
  alarm_description   = "Invocation errors for ${each.value.function_name}"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value.function_name
  }

  alarm_actions = [var.alerts_sns_topic_arn]
}
