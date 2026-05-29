# ROOT: Calls your modules (S3, VPC, IAM, Lambdas)
#
# What goes here:
# - terraform { required_providers { aws = ... } }
# - provider "aws" { region = "eu-central-1" }
# - module "iam"     { source = "./modules/global/iam" ... }
# - module "s3"      { source = "./modules/global/s3" ... }
# - module "vpc"     { source = "./modules/eu-central-1/vpc" ... }
# - module "lambdas" { source = "./modules/eu-central-1/lambdas" ... wiring iam role arns, bucket arns, subnet ids }
