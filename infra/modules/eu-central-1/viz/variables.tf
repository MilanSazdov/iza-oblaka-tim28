variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_sg_id" {
  type = string
}

variable "gold_bucket_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "alerts_sns_topic_arn" {
  type = string
}

variable "awswrangler_layer_arn" {
  type = string
}

variable "ec2_role_name" {
  type = string
}

variable "gold_loader_role_arn" {
  type = string
}

variable "gold_loader_zip_path" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "pg_db" {
  type    = string
  default = "metrics"
}

variable "pg_user" {
  type    = string
  default = "superset"
}

variable "loader_schedule_expression" {
  type    = string
  default = "cron(30 3 * * ? *)"
}
