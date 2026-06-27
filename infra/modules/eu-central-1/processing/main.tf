locals {
  prefix = "${var.project_name}-${var.environment}"
  lambdas = {
    silver_hacker_news = aws_lambda_function.silver_hacker_news
    silver_twitter     = aws_lambda_function.silver_twitter
    gold_metrics       = aws_lambda_function.gold_metrics
  }
}

# silver / gold lambdas

resource "aws_lambda_function" "silver_hacker_news" {
  function_name = "${local.prefix}-silver-hacker-news"
  role          = var.silver_lambda_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 600
  memory_size   = 1536
  layers        = [var.awswrangler_layer_arn]

  filename         = var.silver_hacker_news_zip_path
  source_code_hash = filebase64sha256(var.silver_hacker_news_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  tracing_config { mode = "Active" }

  environment {
    variables = {
      BRONZE_BUCKET = var.bronze_bucket_name
      SILVER_BUCKET = var.silver_bucket_name
    }
  }
}

resource "aws_lambda_function" "silver_twitter" {
  function_name = "${local.prefix}-silver-twitter"
  role          = var.silver_lambda_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 600
  memory_size   = 1536
  layers        = [var.awswrangler_layer_arn]

  filename         = var.silver_twitter_zip_path
  source_code_hash = filebase64sha256(var.silver_twitter_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  tracing_config { mode = "Active" }

  environment {
    variables = {
      BRONZE_BUCKET = var.bronze_bucket_name
      SILVER_BUCKET = var.silver_bucket_name
    }
  }
}

resource "aws_lambda_function" "gold_metrics" {
  function_name = "${local.prefix}-gold-metrics"
  role          = var.gold_lambda_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 600
  memory_size   = 1536
  layers        = [var.awswrangler_layer_arn]

  filename         = var.gold_metrics_zip_path
  source_code_hash = filebase64sha256(var.gold_metrics_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  tracing_config { mode = "Active" }

  environment {
    variables = {
      SILVER_BUCKET = var.silver_bucket_name
      GOLD_BUCKET   = var.gold_bucket_name
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each          = local.lambdas
  name              = "/aws/lambda/${each.value.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.lambdas

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

# Step Functions state machine

resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/vendedlogs/states/${local.prefix}-silver-gold"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "silver_gold" {
  name     = "${local.prefix}-silver-gold"
  role_arn = var.sfn_role_arn

  definition = templatefile("${path.module}/statemachine.json.tftpl", {
    silver_hn_arn    = aws_lambda_function.silver_hacker_news.arn
    silver_x_arn     = aws_lambda_function.silver_twitter.arn
    gold_arn         = aws_lambda_function.gold_metrics.arn
    alerts_topic_arn = var.alerts_sns_topic_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }
}

resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  alarm_name          = "${local.prefix}-silver-gold-failed"
  alarm_description   = "silver-gold pipeline execution failures"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.silver_gold.arn
  }

  alarm_actions = [var.alerts_sns_topic_arn]
}

# daily schedule

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${local.prefix}-silver-gold-daily"
  description         = "Daily silver+gold processing (after bronze ingest)"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "daily" {
  rule     = aws_cloudwatch_event_rule.daily.name
  arn      = aws_sfn_state_machine.silver_gold.arn
  role_arn = var.events_role_arn
  input    = "{}"
}
