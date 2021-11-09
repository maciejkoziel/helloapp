resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block[var.instance_region]
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
}

#Gateway, allows access to
resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw.id
  }
  tags = {
    Name = "default route table"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
  availability_zone       = var.aws_availability_zone[var.instance_region]
  map_public_ip_on_launch = true # Allows access from Internet, bad practice for DB subnet
}
