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
