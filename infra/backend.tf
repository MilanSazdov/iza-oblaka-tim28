terraform {
  backend "s3" {
    bucket         = "iza-oblaka-tim28-tfstate"
    key            = "infra/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "iza-oblaka-tim28-tflock"
    encrypt        = true
  }
}
