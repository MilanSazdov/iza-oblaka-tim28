output "tfstate_bucket_name" {
  value = aws_s3_bucket.tfstate.id
}

output "tflock_table_name" {
  value = aws_dynamodb_table.tflock.id
}
