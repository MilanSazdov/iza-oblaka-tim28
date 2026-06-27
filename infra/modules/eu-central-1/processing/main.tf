locals {
  prefix = "${var.project_name}-${var.environment}"
  lambdas = {
    silver_hacker_news = aws_lambda_function.silver_hacker_news
    silver_twitter     = aws_lambda_function.silver_twitter
    gold_hn            = aws_lambda_function.gold_hn
    gold_twitter       = aws_lambda_function.gold_twitter
  }
}

# silver lambdas

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
  # large static CSV loaded into pandas; more memory also gives more CPU
  memory_size = 4096
  layers      = [var.awswrangler_layer_arn]

  # serialize runs so two CSV uploads can't race on the same X partitions
  reserved_concurrent_executions = 1

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

# gold lambdas: HN runs daily (per date), twitter runs as a whole-dataset batch

resource "aws_lambda_function" "gold_hn" {
  function_name = "${local.prefix}-gold-hn"
  role          = var.gold_lambda_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 300
  memory_size   = 1024
  layers        = [var.awswrangler_layer_arn]

  filename         = var.gold_hn_zip_path
  source_code_hash = filebase64sha256(var.gold_hn_zip_path)

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

resource "aws_lambda_function" "gold_twitter" {
  function_name = "${local.prefix}-gold-twitter"
  role          = var.gold_lambda_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 600
  # reads the whole X dataset to recompute per-date metrics
  memory_size = 4096
  layers      = [var.awswrangler_layer_arn]

  # serialize so two uploads can't race on the same X gold partitions
  reserved_concurrent_executions = 1

  filename         = var.gold_twitter_zip_path
  source_code_hash = filebase64sha256(var.gold_twitter_zip_path)

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

# daily HN pipeline: silver-hacker-news -> gold-hn

resource "aws_cloudwatch_log_group" "sfn_hn" {
  name              = "/aws/vendedlogs/states/${local.prefix}-silver-gold"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "silver_gold" {
  name     = "${local.prefix}-silver-gold"
  role_arn = var.sfn_role_arn

  definition = templatefile("${path.module}/statemachine.json.tftpl", {
    silver_hn_arn    = aws_lambda_function.silver_hacker_news.arn
    gold_hn_arn      = aws_lambda_function.gold_hn.arn
    alerts_topic_arn = var.alerts_sns_topic_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_hn.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }
}

# twitter pipeline: silver-twitter -> gold-twitter (event-driven on CSV upload)

resource "aws_cloudwatch_log_group" "sfn_twitter" {
  name              = "/aws/vendedlogs/states/${local.prefix}-twitter"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "twitter" {
  name     = "${local.prefix}-twitter"
  role_arn = var.sfn_role_arn

  definition = templatefile("${path.module}/statemachine-twitter.json.tftpl", {
    silver_x_arn     = aws_lambda_function.silver_twitter.arn
    gold_x_arn       = aws_lambda_function.gold_twitter.arn
    alerts_topic_arn = var.alerts_sns_topic_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_twitter.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tracing_configuration {
    enabled = true
  }
}

resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  for_each = {
    silver-gold = aws_sfn_state_machine.silver_gold.arn
    twitter     = aws_sfn_state_machine.twitter.arn
  }

  alarm_name          = "${local.prefix}-${each.key}-failed"
  alarm_description   = "${each.key} pipeline execution failures"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = each.value
  }

  alarm_actions = [var.alerts_sns_topic_arn]
}

# daily schedule -> HN pipeline

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${local.prefix}-silver-gold-daily"
  description         = "Daily HN silver+gold processing (after bronze ingest)"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "daily" {
  rule     = aws_cloudwatch_event_rule.daily.name
  arn      = aws_sfn_state_machine.silver_gold.arn
  role_arn = var.events_role_arn
  input    = "{}"
}

# new twitter CSV in bronze -> twitter pipeline (via S3 EventBridge events)

resource "aws_s3_bucket_notification" "bronze" {
  bucket      = var.bronze_bucket_name
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "twitter_upload" {
  name        = "${local.prefix}-twitter-upload"
  description = "Run twitter pipeline when a CSV lands in bronze/source=twitter/"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.bronze_bucket_name] }
      object = { key = [{ prefix = "source=twitter/" }] }
    }
  })
}

resource "aws_cloudwatch_event_target" "twitter_upload" {
  rule     = aws_cloudwatch_event_rule.twitter_upload.name
  arn      = aws_sfn_state_machine.twitter.arn
  role_arn = var.events_role_arn
}
