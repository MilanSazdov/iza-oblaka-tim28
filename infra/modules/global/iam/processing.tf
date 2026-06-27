# IAM roles for the silver/gold processing layers, the Step Functions state
# machine and the EventBridge schedule. Mirrors the least-privilege bronze role.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  sfn_name = "${local.prefix}-silver-gold"
  sfn_arn  = "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${local.sfn_name}"

  silver_fn_arns = "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.prefix}-silver-*"
  gold_fn_arns   = "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.prefix}-gold-*"
}

# shared KMS statement

data "aws_iam_policy_document" "processing_kms" {
  statement {
    actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
    "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

# silver lambda role

resource "aws_iam_role" "silver_lambda" {
  name                 = "${local.prefix}-silver-lambda"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "silver_s3" {
  statement {
    sid       = "ListBuckets"
    actions   = ["s3:ListBucket"]
    resources = [var.bronze_bucket_arn, var.silver_bucket_arn]
  }
  statement {
    sid       = "ReadBronze"
    actions   = ["s3:GetObject"]
    resources = ["${var.bronze_bucket_arn}/source=hacker_news/*", "${var.bronze_bucket_arn}/source=twitter/*"]
  }
  statement {
    sid       = "ReadWriteSilver"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
    resources = ["${var.silver_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "silver_s3" {
  name   = "${local.prefix}-silver-s3"
  role   = aws_iam_role.silver_lambda.id
  policy = data.aws_iam_policy_document.silver_s3.json
}

resource "aws_iam_role_policy" "silver_kms" {
  name   = "${local.prefix}-silver-kms"
  role   = aws_iam_role.silver_lambda.id
  policy = data.aws_iam_policy_document.processing_kms.json
}

data "aws_iam_policy_document" "silver_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-silver-*:*"]
  }
  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-silver-*"]
  }
}

resource "aws_iam_role_policy" "silver_logs" {
  name   = "${local.prefix}-silver-logs"
  role   = aws_iam_role.silver_lambda.id
  policy = data.aws_iam_policy_document.silver_logs.json
}

resource "aws_iam_role_policy_attachment" "silver_vpc" {
  role       = aws_iam_role.silver_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# gold lambda role

resource "aws_iam_role" "gold_lambda" {
  name                 = "${local.prefix}-gold-lambda"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "gold_s3" {
  statement {
    sid       = "ListBuckets"
    actions   = ["s3:ListBucket"]
    resources = [var.silver_bucket_arn, var.gold_bucket_arn]
  }
  statement {
    sid       = "ReadSilver"
    actions   = ["s3:GetObject"]
    resources = ["${var.silver_bucket_arn}/*"]
  }
  statement {
    sid       = "WriteGold"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
    resources = ["${var.gold_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "gold_s3" {
  name   = "${local.prefix}-gold-s3"
  role   = aws_iam_role.gold_lambda.id
  policy = data.aws_iam_policy_document.gold_s3.json
}

resource "aws_iam_role_policy" "gold_kms" {
  name   = "${local.prefix}-gold-kms"
  role   = aws_iam_role.gold_lambda.id
  policy = data.aws_iam_policy_document.processing_kms.json
}

data "aws_iam_policy_document" "gold_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-gold-*:*"]
  }
  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-gold-*"]
  }
}

resource "aws_iam_role_policy" "gold_logs" {
  name   = "${local.prefix}-gold-logs"
  role   = aws_iam_role.gold_lambda.id
  policy = data.aws_iam_policy_document.gold_logs.json
}

resource "aws_iam_role_policy_attachment" "gold_vpc" {
  role       = aws_iam_role.gold_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Step Functions role

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name                 = "${local.prefix}-sfn-silver-gold"
  assume_role_policy   = data.aws_iam_policy_document.sfn_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "sfn" {
  statement {
    sid       = "InvokeProcessingLambdas"
    actions   = ["lambda:InvokeFunction"]
    resources = [local.silver_fn_arns, local.gold_fn_arns]
  }
  statement {
    sid       = "PublishAlerts"
    actions   = ["sns:Publish"]
    resources = [var.alerts_sns_topic_arn]
  }
  statement {
    sid = "StateMachineLogging"
    actions = [
      "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies", "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn" {
  name   = "${local.prefix}-sfn-silver-gold"
  role   = aws_iam_role.sfn.id
  policy = data.aws_iam_policy_document.sfn.json
}

# EventBridge schedule role

data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  name                 = "${local.prefix}-events-silver-gold"
  assume_role_policy   = data.aws_iam_policy_document.events_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "events" {
  statement {
    actions   = ["states:StartExecution"]
    resources = ["arn:aws:states:${local.region}:${local.account_id}:stateMachine:${local.prefix}-*"]
  }
}

resource "aws_iam_role_policy" "events" {
  name   = "${local.prefix}-events-silver-gold"
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.events.json
}
