resource "aws_db_subnet_group" "main" {
  name       = "scoutcloud-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  tags       = { Name = "scoutcloud-db-subnet-group", Project = "scoutcloud" }
}

resource "aws_security_group" "rds" {
  name = "scoutcloud-rds-sg"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Temporary dev access from laptop"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier             = "scoutcloud-db"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "scoutcloud"
  username               = "scoutadmin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
  tags                   = { Name = "scoutcloud-db", Project = "scoutcloud" }
}

output "rds_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}

variable "db_password" {
  description = "Password for RDS"
  type        = string
  sensitive   = true
}
