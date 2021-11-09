resource "aws_security_group" "ecs_tasks_sg" {
  name   = "helloapp-ecs-sg-task"
  vpc_id = data.terraform_remote_state.db_infra.outputs.primary_vpc_id

  ingress {
    protocol         = "tcp"
    from_port        = var.appcontainer_port
    to_port          = var.appcontainer_port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "helloapp-ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "main" {
  name = "helloapp-cluster"
}

resource "aws_ecs_task_definition" "main" {
  family                   = "hello-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  #task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "helloapp-container"
    image     = var.helloapp_image_location
    essential = true
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.appcontainer_port
      hostPort      = var.appcontainer_port
    }],
    "logConfiguration" : {
      "logDriver" : "awslogs",
      "options" : {
        "awslogs-group" : "ecs",
        "awslogs-region" : "eu-west-2",
        "awslogs-stream-prefix" : "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "main" {
  name                               = "ecs-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    subnets         = aws_subnet.ecs_private.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_lb_target_group.id
    container_name   = "helloapp-container"
    container_port   = var.appcontainer_port
  }

  depends_on = [aws_lb_listener.ecs_lb_listener]
}