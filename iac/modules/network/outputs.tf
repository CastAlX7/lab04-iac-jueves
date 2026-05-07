output "private_subnet_a_id" { value = aws_subnet.private_a.id }
output "private_subnet_b_id" { value = aws_subnet.private_b.id }
output "upload_sg_id"        { value = aws_security_group.lambda_sg_upload.id }
output "crop_sg_id"          { value = aws_security_group.lambda_sg_crop.id }
