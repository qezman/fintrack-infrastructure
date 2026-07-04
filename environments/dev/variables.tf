variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as a prefix on all resources"
  type        = string
  default     = "fintrack"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to deploy into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  default     = "fintrack_admin"
}

variable "gmail_app_password" {
  description = "Gmail App Password for Alertmanager email notifications"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "qossim005.online"
}

variable "subdomain" {
  description = "Full app subdomain"
  type        = string
  default     = "fintrack.qossim005.online"
}

variable "elb_dns_name" {
  description = "ELB DNS name for ingress-nginx"
  type        = string
}

variable "elb_zone_id" {
  description = "ELB canonical hosted zone ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL"
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token"
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Telegram chat ID"
  type        = string
}

variable "discord_webhook_url" {
  description = "Discord webhook URL"
  type        = string
  sensitive   = true
}

variable "database_url" {
  description = "Backend Database_URL for Secrets Manager"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Backend JWT_SECRET for Secrets Manager"
  type        = string
  sensitive   = true
}
