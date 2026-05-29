terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "global_s3" {
  source       = "./modules/global/s3"
  project_name = var.project_name
  environment  = var.environment
}

module "global_iam" {
  source       = "./modules/global/iam"
  project_name = var.project_name
  environment  = var.environment

  bronze_bucket_arn = module.global_s3.bronze_bucket_arn
  kms_key_arn       = module.global_s3.kms_key_arn
}

module "eu_vpc" {
  source       = "./modules/eu-central-1/vpc"
  project_name = var.project_name
  environment  = var.environment
}

module "notifications" {
  source       = "./modules/notifications/discord"
  project_name = var.project_name
  environment  = var.environment

  discord_webhook_url       = var.discord_webhook_url
  discord_notifier_zip_path = var.discord_notifier_zip_path
}

module "eu_lambdas" {
  source       = "./modules/eu-central-1/lambdas"
  project_name = var.project_name
  environment  = var.environment

  lambda_execution_role_arn = module.global_iam.lambda_execution_role_arn

  bronze_bucket_name = module.global_s3.bronze_bucket_name
  bronze_bucket_arn  = module.global_s3.bronze_bucket_arn

  private_subnet_ids = module.eu_vpc.private_subnet_ids
  lambda_sg_id       = module.eu_vpc.lambda_sg_id

  hacker_news_zip_path = var.hacker_news_zip_path
  twitter_zip_path     = var.twitter_zip_path

  twitter_dataset_url  = var.twitter_dataset_url
  twitter_dataset_name = var.twitter_dataset_name

  alerts_sns_topic_arn = module.notifications.sns_topic_arn
}
