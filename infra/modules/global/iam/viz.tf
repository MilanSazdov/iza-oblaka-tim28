# IAM for the visualization layer: EC2 (Postgres + Superset) and the gold->Postgres loader lambda.

locals {
  pg_password_param_arn = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${local.prefix}/postgres/password"
}

# EC2 instance role (Postgres + Superset box)

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_postgres" {
  name                 = "${local.prefix}-ec2-postgres"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "ec2_ssm_read" {
  statement {
    sid       = "ReadVizParams"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${local.region}:${local.account_id}:parameter/${local.prefix}/*"]
  }
  statement {
    sid       = "DecryptPgPassword"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "ec2_ssm_read" {
  name   = "${local.prefix}-ec2-ssm-read"
  role   = aws_iam_role.ec2_postgres.id
  policy = data.aws_iam_policy_document.ec2_ssm_read.json
}

# Session Manager access (no SSH)
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_postgres.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# gold-loader lambda role

resource "aws_iam_role" "gold_loader" {
  name                 = "${local.prefix}-gold-loader"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

data "aws_iam_policy_document" "gold_loader" {
  statement {
    sid       = "ReadGold"
    actions   = ["s3:GetObject"]
    resources = ["${var.gold_bucket_arn}/*"]
  }
  statement {
    sid       = "ListGold"
    actions   = ["s3:ListBucket"]
    resources = [var.gold_bucket_arn]
  }
  statement {
    sid       = "Kms"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
  statement {
    sid       = "ReadPgPassword"
    actions   = ["ssm:GetParameter"]
    resources = [local.pg_password_param_arn]
  }
  statement {
    sid       = "Publish"
    actions   = ["sns:Publish"]
    resources = [var.alerts_sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "gold_loader" {
  name   = "${local.prefix}-gold-loader"
  role   = aws_iam_role.gold_loader.id
  policy = data.aws_iam_policy_document.gold_loader.json
}

data "aws_iam_policy_document" "gold_loader_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-gold-loader*:*"]
  }
  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.prefix}-gold-loader*"]
  }
}

resource "aws_iam_role_policy" "gold_loader_logs" {
  name   = "${local.prefix}-gold-loader-logs"
  role   = aws_iam_role.gold_loader.id
  policy = data.aws_iam_policy_document.gold_loader_logs.json
}

resource "aws_iam_role_policy_attachment" "gold_loader_vpc" {
  role       = aws_iam_role.gold_loader.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
