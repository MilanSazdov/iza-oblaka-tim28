variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "silver_lambda_role_arn" {
  type = string
}

variable "gold_lambda_role_arn" {
  type = string
}

variable "sfn_role_arn" {
  type = string
}

variable "events_role_arn" {
  type = string
}

variable "bronze_bucket_name" {
  type = string
}

variable "silver_bucket_name" {
  type = string
}

variable "gold_bucket_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_sg_id" {
  type = string
}

variable "alerts_sns_topic_arn" {
  type = string
}

variable "awswrangler_layer_arn" {
  type = string
}

variable "silver_hacker_news_zip_path" {
  type = string
}

variable "silver_twitter_zip_path" {
  type = string
}

variable "gold_metrics_zip_path" {
  type = string
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 3 * * ? *)"
}
