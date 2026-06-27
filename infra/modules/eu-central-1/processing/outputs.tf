output "state_machine_arn" {
  value = aws_sfn_state_machine.silver_gold.arn
}

output "silver_hacker_news_function_name" {
  value = aws_lambda_function.silver_hacker_news.function_name
}

output "silver_twitter_function_name" {
  value = aws_lambda_function.silver_twitter.function_name
}

output "gold_metrics_function_name" {
  value = aws_lambda_function.gold_metrics.function_name
}
