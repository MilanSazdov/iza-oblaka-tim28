variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_execution_role_arn" {
  type = string
}

variable "bronze_bucket_name" {
  type = string
}

variable "bronze_bucket_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_sg_id" {
  type = string
}

variable "hacker_news_zip_path" {
  type = string
}

variable "twitter_zip_path" {
  type = string
}

variable "twitter_dataset_url" {
  type = string
}

variable "twitter_dataset_name" {
  type = string
}

variable "alerts_sns_topic_arn" {
  type = string
}
