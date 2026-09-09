resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "backup" {
  bucket = "${var.project_name}-backup-${random_string.bucket_suffix.result}"

  tags = {
    Name    = "${var.project_name}-backup"
    Purpose = "Wiz Technical Exercise"
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "backup_access_logs" {
  bucket = "${var.project_name}-backup-logs-${random_string.bucket_suffix.result}"

  tags = {
    Name    = "${var.project_name}-backup-access-logs"
    Purpose = "Wiz Exercise"
  }
}

resource "aws_s3_bucket_public_access_block" "backup_access_logs" {
  bucket = aws_s3_bucket.backup_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_access_logs" {
  bucket = aws_s3_bucket.backup_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "backup_access_logs" {
  bucket = aws_s3_bucket.backup_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "S3ServerAccessLogsPolicy"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.backup_access_logs.arn}/access-logs/*"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.backup.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_logging" "backup" {
  bucket = aws_s3_bucket.backup.id

  target_bucket = aws_s3_bucket.backup_access_logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  # Public read and listing
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "backup_public" {
  depends_on = [aws_s3_bucket_public_access_block.backup]
  bucket     = aws_s3_bucket.backup.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "PublicRead"
        Effect = "Allow"

        Principal = "*"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.backup.arn}/*"
      },
      {
        Sid    = "PublicList"
        Effect = "Allow"

        Principal = "*"

        Action = [
          "s3:ListBucket"
        ]

        Resource = aws_s3_bucket.backup.arn
      }
    ]
  })
}
