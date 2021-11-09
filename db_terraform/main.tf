data "aws_caller_identity" "current" {}

locals {
  primary_region   = "eu-west-2"
  secondary_region = "eu-central-1"
}

#Creates VPC, Subnets, SG and instance with postgress installed for primary instance
module "pg_primary" {
  source = "./modules/pg_deploy"

  instance_region  = local.primary_region
  secondary_region = local.secondary_region
  instance_role    = "primary"
}


#Creates VPC, Subnets, SG and instance with postgress installed for secondary instance
module "pg_secondary" {
  source = "./modules/pg_deploy"

  instance_region  = local.secondary_region
  secondary_region = local.primary_region
  instance_role    = "secondary"
}

#Network section - Binding two VPCs together

#Building VPC Peering
# Requester's side of the connection.
resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = module.pg_primary.vpc_id
  peer_vpc_id   = module.pg_secondary.vpc_id
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_region   = local.secondary_region
  auto_accept   = false
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

#Adding route tables

# Create a route
resource "aws_route" "primary_to_secondary" {
  route_table_id            = module.pg_primary.default_route_table
  destination_cidr_block    = module.pg_secondary.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "secondary_to_primary" {
  provider                  = aws.peer
  route_table_id            = module.pg_secondary.default_route_table
  destination_cidr_block    = module.pg_primary.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id
}

resource "aws_security_group_rule" "primary_to_secondary" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["${module.pg_secondary.private_ip}/32"]
  security_group_id = module.pg_primary.security_group
}

resource "aws_security_group_rule" "secondary_to_primary" {
  provider          = aws.peer
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["${module.pg_primary.private_ip}/32"]
  security_group_id = module.pg_secondary.security_group
}