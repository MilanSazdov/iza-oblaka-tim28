locals {
  prefix = "${var.project_name}-${var.environment}"

  azs = ["eu-central-1a", "eu-central-1b"]
  private_cidrs = {
    "eu-central-1a" = "10.0.1.0/24"
    "eu-central-1b" = "10.0.2.0/24"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.prefix}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = false

  tags = { Name = "${local.prefix}-public-nat" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.prefix}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "${local.prefix}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_subnet" "private" {
  for_each          = local.private_cidrs
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = { Name = "${local.prefix}-private-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.prefix}-rt-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${local.prefix}-rt-private" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
