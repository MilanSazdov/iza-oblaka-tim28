output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  value = aws_iam_role.lambda_execution.name
}

output "notifier_role_arn" {
  value = null
}

output "silver_lambda_role_arn" {
  value = aws_iam_role.silver_lambda.arn
}

output "gold_lambda_role_arn" {
  value = aws_iam_role.gold_lambda.arn
}

output "sfn_role_arn" {
  value = aws_iam_role.sfn.arn
}

output "events_role_arn" {
  value = aws_iam_role.events.arn
}

output "ec2_postgres_role_name" {
  value = aws_iam_role.ec2_postgres.name
}

output "gold_loader_role_arn" {
  value = aws_iam_role.gold_loader.arn
}
