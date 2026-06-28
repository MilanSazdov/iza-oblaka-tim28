variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}

variable "discord_notifier_zip_path" {
  type = string
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}
