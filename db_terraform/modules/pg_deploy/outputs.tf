output "private_ip" {
  value = aws_instance.pg_instance.private_ip
}

output "public_ip" {
  value = aws_instance.pg_instance.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "cidr_block" {
  value = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
}

output "default_route_table" {
  value = aws_default_route_table.route_table.id
}

output "security_group" {
  value = aws_security_group.db_security_group.id
}

output "internet_gw_id" {
  value = aws_internet_gateway.main_gw.id
}


