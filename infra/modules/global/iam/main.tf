# Roles & Policies
#
# What goes here:
# - aws_iam_role "lambda_exec" with trust policy for lambda.amazonaws.com
# - aws_iam_policy with permissions for:
#     - s3:PutObject / GetObject on the data lake buckets (bronze/silver/gold)
#     - logs:CreateLogGroup / CreateLogStream / PutLogEvents (CloudWatch)
#     - vpc network interface perms if lambdas run inside the VPC
# - aws_iam_role_policy_attachment to attach policy to role

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  # Start simple: full access to bronze bucket.
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = ["*"] # later restrict to bronze bucket ARN
  }
}

resource "aws_iam_role_policy" "lambda_execution_policy" {
  name   = "${var.project_name}-${var.environment}-lambda-policy"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}