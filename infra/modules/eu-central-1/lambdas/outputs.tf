output "function_names" {
  value = { for k, fn in local.functions : k => fn.function_name }
}

output "function_arns" {
  value = { for k, fn in local.functions : k => fn.arn }
}

output "log_group_names" {
  value = { for k, lg in aws_cloudwatch_log_group.bronze : k => lg.name }
}
