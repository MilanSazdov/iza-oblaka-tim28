# Exports Bucket ARNs
#
# What goes here:
# - output "bronze_bucket_arn"  { value = aws_s3_bucket.bronze.arn }
# - output "bronze_bucket_name" { value = aws_s3_bucket.bronze.id }
# - output "silver_bucket_arn"  { value = aws_s3_bucket.silver.arn }
# - output "silver_bucket_name" { value = aws_s3_bucket.silver.id }
# - output "gold_bucket_arn"    { value = aws_s3_bucket.gold.arn }
# - output "gold_bucket_name"   { value = aws_s3_bucket.gold.id }

output "bronze_bucket_name" {
  description = "Bronze bucket name"
  value       = aws_s3_bucket.bronze.bucket
}

output "bronze_bucket_arn" {
  description = "Bronze bucket ARN"
  value       = aws_s3_bucket.bronze.arn
}