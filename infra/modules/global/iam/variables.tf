variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "bronze_bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "alerts_sns_topic_arn" {
  type = string
}
