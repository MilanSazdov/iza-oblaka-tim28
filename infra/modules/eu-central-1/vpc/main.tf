# Subnets, NAT Gateway, Security Groups
#
# What goes here:
# - aws_vpc with CIDR (e.g. 10.0.0.0/16)
# - aws_subnet "public" x2 (across two AZs) for NAT Gateway
# - aws_subnet "private" x2 (across two AZs) for Lambdas
# - aws_internet_gateway, aws_eip, aws_nat_gateway
# - aws_route_table (public + private) and route_table_associations
# - aws_security_group "lambda_sg" allowing egress to internet (for API calls to HN / Twitter)
