output "PRIMARY_PUBLIC_IP" {
  value = module.pg_primary.public_ip
}

output "PRIMARY_PRIVATE_IP" {
  value = module.pg_primary.private_ip
}

output "SECONDARY_PUBLIC_IP" {
  value = module.pg_secondary.public_ip
}

output "SECONDARY_PRIVATE_IP" {
  value = module.pg_secondary.private_ip
}

output "primary_vpc_id" {
  value = module.pg_primary.vpc_id
}

output "secondary_vpc_id" {
  value = module.pg_secondary.vpc_id
}

output "primary_security_group" {
  value = module.pg_primary.security_group
}

output "secondary_security_group" {
  value = module.pg_secondary.security_group
}

output "primary_internet_gw_id" {
  value = module.pg_primary.internet_gw_id
}

output "secondary_internet_gw_id" {
  value = module.pg_secondary.internet_gw_id
}
