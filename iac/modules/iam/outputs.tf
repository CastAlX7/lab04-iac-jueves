output "upload_role_arn" {
  value      = aws_iam_role.upload_lambda_role.arn
  depends_on = [aws_iam_role_policy.upload_policy]
}

output "crop_role_arn" {
  value      = aws_iam_role.crop_lambda_role.arn
  depends_on = [aws_iam_role_policy.crop_policy]
}
