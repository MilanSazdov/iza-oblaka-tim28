output "bronze_bucket_name" {
  value = module.global_s3.bronze_bucket_name
}

output "silver_bucket_name" {
  value = module.global_s3.silver_bucket_name
}

output "gold_bucket_name" {
  value = module.global_s3.gold_bucket_name
}

output "vpc_id" {
  value = module.eu_vpc.vpc_id
}

output "alerts_sns_topic_arn" {
  value = module.notifications.sns_topic_arn
}
