terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    random = { source = "hashicorp/random" }
  }
}

locals {
  prefix       = "${var.project_name}-${var.environment}"
  pg_param     = "/${local.prefix}/postgres/password"
  admin_param  = "/${local.prefix}/superset/admin_password"
  secret_param = "/${local.prefix}/superset/secret_key"
}

# secrets (generated, stored in SSM SecureString with our KMS key)

resource "random_password" "pg" {
  length  = 24
  special = false
}

resource "random_password" "superset_admin" {
  length  = 20
  special = false
}

resource "random_password" "superset_secret" {
  length  = 42
  special = false
}

resource "aws_ssm_parameter" "pg_password" {
  name   = local.pg_param
  type   = "SecureString"
  key_id = var.kms_key_arn
  value  = random_password.pg.result
}

resource "aws_ssm_parameter" "superset_admin" {
  name   = local.admin_param
  type   = "SecureString"
  key_id = var.kms_key_arn
  value  = random_password.superset_admin.result
}

resource "aws_ssm_parameter" "superset_secret" {
  name   = local.secret_param
  type   = "SecureString"
  key_id = var.kms_key_arn
  value  = random_password.superset_secret.result
}

# security group: Postgres from lambda only, Superset from teammate IPs only

resource "aws_security_group" "ec2" {
  name        = "${local.prefix}-viz-sg"
  description = "Postgres from lambda SG only; no public ingress (access via SSM)"
  vpc_id      = var.vpc_id

  tags = { Name = "${local.prefix}-viz-sg" }
}

# only the loader lambda can reach Postgres; Superset has NO inbound rule
# (reached via SSM port-forwarding, which bypasses the security group)
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = var.lambda_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# EC2 instance (Postgres + Superset)

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.prefix}-viz"
  role = var.ec2_role_name
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"] # standard (not -minimal-) AL2023
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "viz" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0] # private subnet, no public IP
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    region       = data.aws_region.current.name
    pg_param     = local.pg_param
    admin_param  = local.admin_param
    secret_param = local.secret_param
    pg_db        = var.pg_db
    pg_user      = var.pg_user
  })

  tags = { Name = "${local.prefix}-viz" }

  # don't stop/start the running box on template edits; applies on rebuild
  lifecycle {
    ignore_changes = [user_data]
  }

  depends_on = [
    aws_ssm_parameter.pg_password,
    aws_ssm_parameter.superset_admin,
    aws_ssm_parameter.superset_secret,
  ]
}

data "aws_region" "current" {}

# gold -> Postgres loader lambda

resource "aws_lambda_function" "gold_loader" {
  function_name = "${local.prefix}-gold-loader"
  role          = var.gold_loader_role_arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 300
  memory_size   = 1024
  layers        = [var.awswrangler_layer_arn]

  filename         = var.gold_loader_zip_path
  source_code_hash = filebase64sha256(var.gold_loader_zip_path)

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  tracing_config { mode = "Active" }

  environment {
    variables = {
      GOLD_BUCKET     = var.gold_bucket_name
      PG_HOST         = aws_instance.viz.private_ip
      PG_PORT         = "5432"
      PG_DB           = var.pg_db
      PG_USER         = var.pg_user
      PG_PASSWORD_SSM = local.pg_param
    }
  }
}

resource "aws_cloudwatch_log_group" "gold_loader" {
  name              = "/aws/lambda/${aws_lambda_function.gold_loader.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "gold_loader_errors" {
  alarm_name          = "${aws_lambda_function.gold_loader.function_name}-errors"
  alarm_description   = "Invocation errors for the gold->postgres loader"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.gold_loader.function_name
  }

  alarm_actions = [var.alerts_sns_topic_arn]
}

# daily load (after the gold pipelines); also manually invocable

resource "aws_cloudwatch_event_rule" "loader_daily" {
  name                = "${local.prefix}-gold-loader-daily"
  description         = "Daily load of gold metrics into Postgres"
  schedule_expression = var.loader_schedule_expression
}

resource "aws_cloudwatch_event_target" "loader_daily" {
  rule = aws_cloudwatch_event_rule.loader_daily.name
  arn  = aws_lambda_function.gold_loader.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gold_loader.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.loader_daily.arn
}
