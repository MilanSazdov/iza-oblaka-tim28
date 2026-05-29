# ROOT: Calls your modules (S3, VPC, IAM, Lambdas)
#
# What goes here:
# - terraform { required_providers { aws = ... } }
# - provider "aws" { region = "eu-central-1" }
# - module "iam"     { source = "./modules/global/iam" ... }
# - module "s3"      { source = "./modules/global/s3" ... }
# - module "vpc"     { source = "./modules/eu-central-1/vpc" ... }
# - module "lambdas" { source = "./modules/eu-central-1/lambdas" ... wiring iam role arns, bucket arns, subnet ids }

provider "aws" {
  region = var.aws_region
}

module "global_iam" {
  source      = "./modules/global/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "global_s3" {
  source       = "./modules/global/s3"
  project_name = var.project_name
  environment  = var.environment
}

module "eu_vpc" {
  source       = "./modules/eu-central-1/vpc"
  project_name = var.project_name
  environment  = var.environment
}

module "eu_lambdas" {
  source       = "./modules/eu-central-1/lambdas"
  project_name = var.project_name
  environment  = var.environment

  # Inputs from other modules:
  bronze_bucket_arn = module.global_s3.bronze_bucket_arn
  bronze_bucket_name = module.global_s3.bronze_bucket_name

  lambda_execution_role_arn = module.global_iam.lambda_execution_role_arn
}