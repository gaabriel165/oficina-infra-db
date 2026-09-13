terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "oficina-api-terraform-state-728750563430"
    key          = "db/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Repo      = "oficina-infra-db"
    }
  }
}
