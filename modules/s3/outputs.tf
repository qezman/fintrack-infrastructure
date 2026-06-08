output "bucket_name" {
  description = "Name of the receipts S3 bucket"
  value       = aws_s3_bucket.receipts.bucket
}

output "bucket_arn" {
  description = "ARN of the receipts S3 bucket"
  value       = aws_s3_bucket.receipts.arn
}
