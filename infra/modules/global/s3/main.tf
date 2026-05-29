# The Data Lake Bronze/Silver/Gold buckets
#
# What goes here:
# - aws_s3_bucket "bronze" - raw ingested data (hacker_news, twitter)
# - aws_s3_bucket "silver" - cleaned/normalized
# - aws_s3_bucket "gold"   - curated/aggregated
# - aws_s3_bucket_versioning, aws_s3_bucket_server_side_encryption_configuration
# - aws_s3_bucket_public_access_block for each (block all public access)
# - optional: lifecycle rules to transition old objects to Glacier

locals {
  prefix = "${var.project_name}-${var.environment}"
}

resource "aws_s3_bucket" "bronze" {
  bucket = "${local.prefix}-bronze"
}

resource "aws_s3_bucket" "silver" {
  bucket = "${local.prefix}-silver"
}

resource "aws_s3_bucket" "gold" {
  bucket = "${local.prefix}-gold"
}