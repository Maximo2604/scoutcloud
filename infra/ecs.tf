resource "aws_iam_role" "ecs_task" {
  name = "scoutcloud-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
      Resource = aws_dynamodb_table.live_scores.arn
    }]
  })
}

resource "aws_iam_role" "ecs_execution" {
  name = "scoutcloud-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "main" {
  name = "scoutcloud"
  tags = { Project = "scoutcloud" }
}

resource "aws_cloudwatch_log_group" "score_fetcher" {
  name              = "/ecs/scoutcloud/score-fetcher"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "score_fetcher" {
  family                   = "scoutcloud-score-fetcher"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  container_definitions = jsonencode([{
    name      = "score-fetcher"
    image     = "${aws_ecr_repository.score_fetcher.repository_url}:latest"
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.score_fetcher.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_security_group" "ecs_tasks" {
  name        = "scoutcloud-ecs-tasks-sg"
  description = "ECS tasks - egress only"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "scoutcloud-ecs-tasks-sg", Project = "scoutcloud" }
}

resource "aws_security_group" "vpce" {
  name        = "scoutcloud-vpce-sg"
  description = "VPC endpoints - HTTPS from ECS tasks only"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "scoutcloud-vpce-sg", Project = "scoutcloud" }
}

locals { vpce_region = "us-east-1" }

data "aws_route_tables" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids
  tags = { Name = "scoutcloud-vpce-s3", Project = "scoutcloud" }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
  tags = { Name = "scoutcloud-vpce-ecr-api", Project = "scoutcloud" }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
  tags = { Name = "scoutcloud-vpce-ecr-dkr", Project = "scoutcloud" }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
  tags = { Name = "scoutcloud-vpce-logs", Project = "scoutcloud" }
}

resource "aws_ecs_service" "score_fetcher" {
  name            = "score-fetcher"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.score_fetcher.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_tasks.id]
  }
  tags = { Project = "scoutcloud" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/scoutcloud-app"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "app" {
  family                   = "scoutcloud-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([{
    name  = "scoutcloud-app"
    image = "${aws_ecr_repository.app.repository_url}:latest"
    portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }]
    environment = [
      { name = "DATABASE_URL", value = "postgresql://scoutadmin:ScDb!R3c0rds%232026@${aws_db_instance.main.endpoint}/scoutcloud" },
      { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.live_scores.name },
      { name = "AWS_REGION", value = "us-east-1" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/scoutcloud-app"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])
}
