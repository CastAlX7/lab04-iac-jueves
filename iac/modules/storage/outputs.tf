output "bucket_id"  { value = aws_s3_bucket.images.id }
output "bucket_arn" { value = aws_s3_bucket.images.arn }
output "queue_arn"  { value = aws_sqs_queue.image_queue.arn }
output "dlq_arn"    { value = aws_sqs_queue.image_dlq.arn }
