# Inputs for the lambdas module
#
# What goes here:
# - variable "lambda_role_arn"     {}    # from modules/global/iam
# - variable "bronze_bucket_name"  {}    # from modules/global/s3
# - variable "private_subnet_ids"  { type = list(string) }   # from modules/eu-central-1/vpc
# - variable "lambda_sg_id"        {}    # from modules/eu-central-1/vpc
# - variable "environment"         {}
