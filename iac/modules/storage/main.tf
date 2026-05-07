# ── S3 BUCKET ───────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "images" {
  bucket = replace(lower("${var.project_name}-storage-${terraform.workspace}"), "_", "-")

  tags = {
    Name        = "${var.project_name}-bucket-${terraform.workspace}"
    Environment = terraform.workspace
    Project     = var.project_name
  }
}

resource "aws_s3_object" "uploads_folder" {
  bucket = aws_s3_bucket.images.id
  key    = "uploads/"
}

resource "aws_s3_object" "processed_folder" {
  bucket = aws_s3_bucket.images.id
  key    = "processed/"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "expire-uploads"
    status = "Enabled"
    filter { prefix = "uploads/" }
    expiration { days = 30 }
  }

  rule {
    id     = "expire-processed"
    status = "Enabled"
    filter { prefix = "processed/" }
    expiration { days = 90 }
  }
}

resource "aws_s3_bucket_public_access_block" "images_access" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_sqs_queue_policy.image_queue_policy]
}

# ── SQS ─────────────────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "image_queue" {
  name                       = "image-processor-${terraform.workspace}-image-queue"
  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
  }
}

resource "aws_sqs_queue_policy" "image_queue_policy" {
  queue_url = aws_sqs_queue.image_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.image_queue.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.images.arn } }
    }]
  })
}

# ── DLQ + ALARMA ────────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "image_dlq" {
  name                      = "image-processor-${terraform.workspace}-image-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sns_topic" "dlq_alarm_topic" {
  name = "dlq-alarm-${terraform.workspace}-topic"
}

resource "aws_sns_topic_subscription" "dlq_email" {
  topic_arn = aws_sns_topic.dlq_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "dlq-messages-${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Mensajes estancados en la DLQ"

  dimensions    = { QueueName = aws_sqs_queue.image_dlq.name }
  alarm_actions = [aws_sns_topic.dlq_alarm_topic.arn]
}
