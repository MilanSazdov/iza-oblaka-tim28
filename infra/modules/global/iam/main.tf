# Roles & Policies
#
# What goes here:
# - aws_iam_role "lambda_exec" with trust policy for lambda.amazonaws.com
# - aws_iam_policy with permissions for:
#     - s3:PutObject / GetObject on the data lake buckets (bronze/silver/gold)
#     - logs:CreateLogGroup / CreateLogStream / PutLogEvents (CloudWatch)
#     - vpc network interface perms if lambdas run inside the VPC
# - aws_iam_role_policy_attachment to attach policy to role
