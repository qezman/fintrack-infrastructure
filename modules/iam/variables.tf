variable "project" {
  description = "Project name used as a prefix on all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  type        = string
}

variable "receipts_bucket_arn" {
  description = "ARN of the S3 receipts bucket"
  type        = string
}

variable "github_org" {
  description = "GitHub username"
  type        = string
  default     = "qezman"
}
