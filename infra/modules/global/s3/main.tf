locals {
  prefix = "${var.project_name}-${var.environment}"
  tiers  = toset(["bronze", "silver", "gold"])
}

resource "aws_kms_key" "s3" {
  description             = "${local.prefix}-s3"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${local.prefix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_s3_bucket" "tier" {
  for_each = local.tiers
  bucket   = "${local.prefix}-${each.key}"
}

resource "aws_s3_bucket_versioning" "tier" {
  for_each = aws_s3_bucket.tier
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tier" {
  for_each = aws_s3_bucket.tier
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tier" {
  for_each                = aws_s3_bucket.tier
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tier" {
  for_each = aws_s3_bucket.tier
  bucket   = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "tls_only" {
  for_each = aws_s3_bucket.tier
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      each.value.arn,
      "${each.value.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  for_each = aws_s3_bucket.tier
  bucket   = each.value.id
  policy   = data.aws_iam_policy_document.tls_only[each.key].json
}
