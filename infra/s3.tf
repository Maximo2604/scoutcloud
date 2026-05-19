resource "random_id" "bucket_suffix" { byte_length = 4 }

resource "aws_s3_bucket" "assets" {
  bucket = "scoutcloud-assets-${random_id.bucket_suffix.hex}"
  tags   = { Name = "scoutcloud-assets", Project = "scoutcloud" }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "move-logs-to-ia"
    status = "Enabled"

    filter { prefix = "logs/" }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration { days = 365 }
  }
}

output "bucket_name" { value = aws_s3_bucket.assets.bucket }
