# aws_lambda_function resources and CloudWatch Crons
#
# What goes here:
# - data "archive_file" to zip lambdas/bronze/hacker_news and lambdas/bronze/twitter
# - aws_lambda_function "hacker_news" (runtime python3.x, handler = handler.lambda_handler,
#     role = var.lambda_role_arn, vpc_config = { subnet_ids, security_group_ids })
# - aws_lambda_function "twitter" (same shape)
# - aws_cloudwatch_event_rule "schedule" with rate(...) for each lambda
# - aws_cloudwatch_event_target wiring rule -> lambda
# - aws_lambda_permission allowing EventBridge to invoke each lambda
