locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"
}

data "aws_iam_policy_document" "notifier_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notifier" {
  name               = "${local.prefix}-discord-notifier"
  assume_role_policy = data.aws_iam_policy_document.notifier_assume.json
}

resource "aws_iam_role_policy_attachment" "notifier_logs" {
  role       = aws_iam_role.notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "notifier" {
  function_name = "${local.prefix}-discord-notifier"
  role          = aws_iam_role.notifier.arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 30
  memory_size   = 128

  filename         = var.discord_notifier_zip_path
  source_code_hash = filebase64sha256(var.discord_notifier_zip_path)

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

resource "aws_cloudwatch_log_group" "notifier" {
  name              = "/aws/lambda/${aws_lambda_function.notifier.function_name}"
  retention_in_days = 14
}

resource "aws_sns_topic_subscription" "notifier" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notifier.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}
