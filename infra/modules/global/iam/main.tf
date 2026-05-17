locals {
  prefix = "${var.project_name}-${var.environment}"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${local.prefix}-bronze-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "bronze_write" {
  statement {
    sid       = "ListBronzeBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.bronze_bucket_arn]
  }

  statement {
    sid     = "WriteBronzeSourcePrefixes"
    actions = ["s3:PutObject", "s3:GetObject", "s3:AbortMultipartUpload"]
    resources = [
      "${var.bronze_bucket_arn}/source=hacker_news/*",
      "${var.bronze_bucket_arn}/source=twitter/*",
    ]
  }
}

resource "aws_iam_role_policy" "bronze_write" {
  name   = "${local.prefix}-bronze-write"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.bronze_write.json
}

data "aws_iam_policy_document" "logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-bronze-*:*",
    ]
  }

  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-bronze-*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "${local.prefix}-bronze-logs"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.logs.json
}

data "aws_iam_policy_document" "kms" {
  statement {
    actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
               "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "kms" {
  name   = "${local.prefix}-bronze-kms"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.kms.json
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
