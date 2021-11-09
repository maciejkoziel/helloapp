resource "aws_security_group" "db_security_group" {
  name        = "PostgreSQL"
  description = "DB security group"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "allow_egress_all" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  security_group_id = aws_security_group.db_security_group.id
}

resource "aws_security_group_rule" "allow_ssh_from_world" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db_security_group.id
}


#Postgres instance, for demo I am not using EBS volume, all data stored in this instance are ephemeral 
resource "aws_instance" "pg_instance" {
  ami           = var.instance_amis[var.instance_region] # Amazon Linux
  instance_type = var.instance_type
  key_name      = aws_key_pair.ssh_key.key_name
  user_data = templatefile("${abspath(path.module)}/templates/postgress_install.sh", {
    pg_hba_file = templatefile("${abspath(path.module)}/templates/pg_hba.conf", { subnets = aws_vpc.main.cidr_block }),
  })
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.db_security_group.id]
}