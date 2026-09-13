output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host)"
  value       = aws_db_instance.this.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  description = "Security group attached to the database"
  value       = aws_security_group.db.id
}

output "db_client_security_group_id" {
  description = "Security group that grants PostgreSQL access to workloads outside the cluster"
  value       = aws_security_group.db_client.id
}

output "database_url_parameter_name" {
  description = "SSM parameter holding the full connection string"
  value       = aws_ssm_parameter.database_url.name
}

output "database_url" {
  description = "Full connection string for the application"
  value       = local.database_url
  sensitive   = true
}
