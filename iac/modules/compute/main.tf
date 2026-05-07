# ── UPLOAD LAMBDA ───────────────────────────────────────────────────────────────
data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/lambdas/upload"
  output_path = "${path.module}/../../upload_function.zip"
}

resource "aws_lambda_function" "upload_lambda" {
  function_name    = "upload-lambda-${terraform.workspace}"
  role             = var.upload_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_group_ids = [var.upload_sg_id]
  }

  environment {
    variables = {
      S3_BUCKET     = var.bucket_id
      UPLOAD_PREFIX = "uploads/"
    }
  }
}

resource "aws_cloudwatch_log_group" "upload_logs" {
  name              = "/aws/lambda/${aws_lambda_function.upload_lambda.function_name}"
  retention_in_days = 14
}

# ── CROP LAMBDA ─────────────────────────────────────────────────────────────────
data "archive_file" "crop_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/lambdas/crop"
  output_path = "${path.module}/../../crop_function.zip"
}

resource "aws_lambda_function" "crop_lambda" {
  function_name    = "crop-lambda-${terraform.workspace}"
  role             = var.crop_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.crop_zip.output_path
  source_code_hash = data.archive_file.crop_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_group_ids = [var.crop_sg_id]
  }

  environment {
    variables = {
      S3_BUCKET        = var.bucket_id
      PROCESSED_PREFIX = "processed/"
    }
  }
}

resource "aws_cloudwatch_log_group" "crop_logs" {
  name              = "/aws/lambda/${aws_lambda_function.crop_lambda.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn        = var.queue_arn
  function_name           = aws_lambda_function.crop_lambda.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}

# ── API GATEWAY ─────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-${terraform.workspace}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-${terraform.workspace}"
  retention_in_days = 14
}

resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      protocol       = "$context.protocol"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      error          = "$context.authorizer.error"
    })
  }
}

resource "aws_lambda_permission" "apigw_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}
