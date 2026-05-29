# ROOT: Final outputs
#
# What goes here:
# - output "data_lake_bucket_name" { value = module.s3.bronze_bucket_name }
# - output "silver_bucket_name"    { value = module.s3.silver_bucket_name }
# - output "gold_bucket_name"      { value = module.s3.gold_bucket_name }
# - output "lambda_role_arn"       { value = module.iam.lambda_role_arn }
# - output "vpc_id"                { value = module.vpc.vpc_id }

# TODO: rename bronze bucket name

output "bronze_bucket_name" {
  description = "Bronze data lake bucket"
  value       = module.global_s3.bronze_bucket_name
}