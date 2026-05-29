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
