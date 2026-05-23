terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.app_name
      ManagedBy   = "Terraform"
    }
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "The target AWS Region for all serverless resources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment naming stage (e.g. dev, staging, prod)"
}

variable "app_name" {
  type        = string
  default     = "life-xp"
  description = "Application namespace prefix"
}
