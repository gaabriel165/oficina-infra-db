variable "region" {
  description = "AWS region to provision into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "oficina-api"
}

variable "state_bucket" {
  description = "S3 bucket holding the Terraform state of the other repositories"
  type        = string
  default     = "oficina-api-terraform-state-728750563430"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS"
  type        = string
  default     = "16.15"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "oficina_mecanica"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

variable "db_allocated_storage" {
  description = "Storage size in GiB"
  type        = number
  default     = 20
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days"
  type        = number
  default     = 1
}
