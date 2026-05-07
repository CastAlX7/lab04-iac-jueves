# ── UPLOAD LAMBDA ROLE ──────────────────────────────────────────────────────────
resource "aws_iam_role" "upload_lambda_role" {
  name = "${var.project_name}-${terraform.workspace}-upload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "upload_policy" {
  name = "upload-limited-policy"
  role = aws_iam_role.upload_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${var.bucket_arn}/uploads/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"]
        Resource = ["*"]
      }
    ]
  })
}

# ── CROP LAMBDA ROLE ────────────────────────────────────────────────────────────
resource "aws_iam_role" "crop_lambda_role" {
  name = "${var.project_name}-${terraform.workspace}-crop-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "crop_policy" {
  name = "crop-limited-policy"
  role = aws_iam_role.crop_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${var.bucket_arn}/uploads/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${var.bucket_arn}/processed/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
        Resource = [var.queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"]
        Resource = ["*"]
      }
    ]
  })
}

# ── API GATEWAY CLOUDWATCH ROLE ─────────────────────────────────────────────────
resource "aws_iam_role" "api_gw_cloudwatch" {
  name = "${var.project_name}-${terraform.workspace}-api-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "apigateway.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gw_cloudwatch_policy" {
  role       = aws_iam_role.api_gw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
