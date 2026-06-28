variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type    = string
  default = "iza-oblaka-tim28"
}

variable "hacker_news_zip_path" {
  type    = string
  default = "build/hacker_news.zip"
}

variable "twitter_zip_path" {
  type    = string
  default = "build/twitter.zip"
}

variable "discord_notifier_zip_path" {
  type    = string
  default = "build/discord.zip"
}

variable "silver_hacker_news_zip_path" {
  type    = string
  default = "build/silver_hacker_news.zip"
}

variable "silver_twitter_zip_path" {
  type    = string
  default = "build/silver_twitter.zip"
}

variable "gold_hn_zip_path" {
  type    = string
  default = "build/gold_hn.zip"
}

variable "gold_twitter_zip_path" {
  type    = string
  default = "build/gold_twitter.zip"
}

variable "gold_loader_zip_path" {
  type    = string
  default = "build/gold_loader.zip"
}

variable "viz_instance_type" {
  type    = string
  default = "t3.micro" # account is Free-Tier-only; 1 GB + swap (see user-data)
}

# AWS-managed "AWS SDK for pandas" (awswrangler) layer for python3.11 in
# eu-central-1. Confirm the latest version number for your account/region:
# https://aws-sdk-pandas.readthedocs.io/en/stable/layers.html
variable "awswrangler_layer_arn" {
  type    = string
  default = "arn:aws:lambda:eu-central-1:336392948345:layer:AWSSDKPandas-Python311:22"
}

variable "twitter_dataset_url" {
  type    = string
  default = "https://raw.githubusercontent.com/datasets/bitcoin-tweets-sample/main/tweets.csv"
}

variable "twitter_dataset_name" {
  type    = string
  default = "bitcoin-tweets"
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}

variable "lambda_role_permissions_boundary_arn" {
  type    = string
  default = "arn:aws:iam::278371787079:policy/boundary-git-actions"
}
