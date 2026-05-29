# ROOT: Remote S3 state & DynamoDB lock config
#
# What goes here:
# terraform {
#   backend "s3" {
#     bucket         = "<your-tfstate-bucket>"
#     key            = "infra/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "<your-tf-lock-table>"
#     encrypt        = true
#   }
# }
