# S3 bucket for receipt image uploads
resource "aws_s3_bucket" "receipts" {
  bucket = "${var.project}-${var.environment}-receipts-${var.aws_account_id}"

  tags = {
    Name = "${var.project}-${var.environment}-receipts"
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration
resource "aws_s3_bucket_cors_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  cors_rule {
    allowed_origins = ["*"]

    # PUT: browser uploads using a presigned URL
    # GET: for downloading/viewing receipts
    allowed_methods = ["PUT", "GET"]

    allowed_headers = ["*"]

    # time the browser caches the CORS preflight response
    max_age_seconds = 3000
  }
}

# Lifecycle rule
resource "aws_s3_bucket_lifecycle_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  rule {
    id     = "expire-old-receipts"
    status = "Enabled"

    # applies to all objects in the bucket
    filter {}

    expiration {
      days = 90
    }
  }
}
