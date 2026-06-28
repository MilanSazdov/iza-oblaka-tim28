resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${local.prefix}-vpce-s3" }
}

# Interface endpoints so SSM Session Manager works privately (no internet
# round-trip): the EC2 SSM agent + lambda GetParameter reach AWS in-VPC.
resource "aws_security_group" "vpce" {
  name        = "${local.prefix}-vpce-sg"
  description = "HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = { Name = "${local.prefix}-vpce-sg" }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(["ssm", "ssmmessages", "ec2messages"])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.eu-central-1.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = { Name = "${local.prefix}-vpce-${each.key}" }
}

resource "aws_security_group" "lambda" {
  name        = "${local.prefix}-lambda-sg"
  description = "Egress only for bronze ingest lambdas"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # reach Postgres on the viz EC2 (inside the VPC only)
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = { Name = "${local.prefix}-lambda-sg" }
}
