output "bronze_bucket_name" {
  value = aws_s3_bucket.tier["bronze"].bucket
}

output "bronze_bucket_arn" {
  value = aws_s3_bucket.tier["bronze"].arn
}

output "silver_bucket_name" {
  value = aws_s3_bucket.tier["silver"].bucket
}

output "silver_bucket_arn" {
  value = aws_s3_bucket.tier["silver"].arn
}

output "gold_bucket_name" {
  value = aws_s3_bucket.tier["gold"].bucket
}

output "gold_bucket_arn" {
  value = aws_s3_bucket.tier["gold"].arn
}

output "kms_key_arn" {
  value = aws_kms_key.s3.arn
}
