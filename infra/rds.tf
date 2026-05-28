resource "aws_db_subnet_group" "main" {
  name       = "scoutcloud-db-subnet-group-v2"
  subnet_ids = module.network.isolated_subnet_ids
  tags       = { Name = "scoutcloud-db-subnet-group", Project = "scoutcloud" }
}

resource "aws_security_group" "rds" {
 name = "scoutcloud-rds-sg-v2"
 vpc_id = module.network.vpc_id

 ingress {
 from_port = 5432
 to_port = 5432
 protocol = "tcp"
 cidr_blocks = ["10.0.0.0/16"]
 description = "Allow from app servers in VPC"
 }

 egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
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
  publicly_accessible    = false
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
