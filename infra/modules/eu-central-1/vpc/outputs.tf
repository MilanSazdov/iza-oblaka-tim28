output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}
