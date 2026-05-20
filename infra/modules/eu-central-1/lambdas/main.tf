locals {
  prefix = "${var.project_name}-${var.environment}"
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

  tracing_config {
    mode = "Active"
  }

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

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      BRONZE_BUCKET = var.bronze_bucket_name
      DATASET_URL   = var.twitter_dataset_url
      DATASET_NAME  = var.twitter_dataset_name
    }
  }
}
