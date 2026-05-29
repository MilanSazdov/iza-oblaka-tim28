# ROOT: Global variables
#
# What goes here:
# - variable "environment" { default = "dev" }
# - variable "aws_region"  { default = "eu-central-1" }
# - variable "project_name" { default = "iza-oblaka-tim28" }
# - any other shared inputs (tags, account id, etc.)
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod, ...)"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Project base name"
  default     = "iza-oblaka-tim28"
}