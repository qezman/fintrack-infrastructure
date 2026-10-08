variable "aws_region" {
  description = "AWS region for S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Unique S3 bucket for Terraform state"
  type        = string
  default     = "fintrack-state-722965867897"
}

variable "lock_table_state" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "fintrack-Terraform-locks"
}
