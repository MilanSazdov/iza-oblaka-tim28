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
