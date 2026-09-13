locals {
  database_url = "postgres://${var.db_username}:${random_password.db.result}@${aws_db_instance.this.address}:5432/${var.db_name}?sslmode=require"
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.project_name}/database_url"
  description = "Connection string consumed by the API deploy and the authentication Lambda"
  type        = "SecureString"
  value       = local.database_url
}
