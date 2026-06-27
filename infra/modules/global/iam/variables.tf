variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "bronze_bucket_arn" {
  type = string
}

variable "silver_bucket_arn" {
  type = string
}

variable "gold_bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "alerts_sns_topic_arn" {
  type = string
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}
