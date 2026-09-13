resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db"
  subnet_ids = local.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db"
  description = "PostgreSQL access from the EKS worker nodes and the authentication Lambda"
  vpc_id      = local.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [local.node_security_group_id]
  }

  ingress {
    description     = "PostgreSQL from the authentication Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.db_client.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_client" {
  name        = "${var.project_name}-db-client"
  description = "Attach to any workload outside the cluster that must reach the database"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.project_name}-pg16"
  family = "postgres16"

  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  multi_az               = false
  publicly_accessible    = false

  backup_retention_period         = var.db_backup_retention_days
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = true

  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true
}
