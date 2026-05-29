# Exports Role ARNs
#
# What goes here:
# - output "lambda_role_arn"  { value = aws_iam_role.lambda_exec.arn }
# - output "lambda_role_name" { value = aws_iam_role.lambda_exec.name }

output "lambda_execution_role_arn" {
  description = "IAM role ARN for Lambda execution"
  value       = aws_iam_role.lambda_execution.arn
}