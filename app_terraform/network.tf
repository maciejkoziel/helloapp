resource "aws_subnet" "ecs_public" {
  count                   = 2
  cidr_block              = cidrsubnet(data.aws_vpc.main.cidr_block, 8, 40 + count.index)
  availability_zone       = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id                  = data.terraform_remote_state.db_infra.outputs.primary_vpc_id
  map_public_ip_on_launch = true
  tags = {
    Name = "ECS Public #${count.index}"
  }
}

resource "aws_subnet" "ecs_private" {
  count             = 2
  cidr_block        = cidrsubnet(data.aws_vpc.main.cidr_block, 8, 20 + count.index)
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id            = data.terraform_remote_state.db_infra.outputs.primary_vpc_id
  tags = {
    Name = "ECS Private #${count.index}"
  }
}

resource "aws_security_group_rule" "ecs_to_db" {
  count             = length(aws_subnet.ecs_private)
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [cidrsubnet(data.aws_vpc.main.cidr_block, 8, 20 + count.index)]
  security_group_id = data.terraform_remote_state.db_infra.outputs.primary_security_group
  description       = "ECS to DB #${count.index}"
}


resource "aws_eip" "ecs_gateway" {
  count = 2
  vpc   = true
}

resource "aws_nat_gateway" "ecs_gateway" {
  count         = 2
  subnet_id     = element(aws_subnet.ecs_public.*.id, count.index)
  allocation_id = element(aws_eip.ecs_gateway.*.id, count.index)
}

resource "aws_route_table" "ecs_private" {
  count  = 2
  vpc_id = data.terraform_remote_state.db_infra.outputs.primary_vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.ecs_gateway.*.id, count.index)
  }
}

resource "aws_route_table_association" "ecs_private" {
  count          = 2
  subnet_id      = element(aws_subnet.ecs_private.*.id, count.index)
  route_table_id = element(aws_route_table.ecs_private.*.id, count.index)
}


resource "aws_security_group" "ecs_lb" {
  name   = "ecs-alb-security-group"
  vpc_id = data.terraform_remote_state.db_infra.outputs.primary_vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "ecs_lb" {
  name            = "ecs-lb"
  subnets         = aws_subnet.ecs_public.*.id
  security_groups = [aws_security_group.ecs_lb.id]
}

resource "aws_lb_target_group" "ecs_lb_target_group" {
  name        = "ecs-lb-target-group"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.db_infra.outputs.primary_vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/health"
    unhealthy_threshold = "2"
  }
}

resource "aws_lb_listener" "ecs_lb_listener" {
  load_balancer_arn = aws_lb.ecs_lb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.ecs_lb_target_group.id
    type             = "forward"
  }
}