# ── VPC ────────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-${terraform.workspace}-vpc" }
}

# ── INTERNET GATEWAY ────────────────────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Project     = "${var.project_name}-igw"
    Environment = terraform.workspace
  }
}

# ── SUBNETS ─────────────────────────────────────────────────────────────────────
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_a_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Project     = "${var.project_name}-pub-sub-a"
    Environment = terraform.workspace
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Project     = "${var.project_name}-pub-sub-b"
    Environment = terraform.workspace
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.priv_subnet_a_cidr
  availability_zone = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-${terraform.workspace}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.priv_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = { Name = "${var.project_name}-${terraform.workspace}-private-b" }
}

# ── ELASTIC IPs + NAT GATEWAYS ──────────────────────────────────────────────────
resource "aws_eip" "nat_a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = { Project = "${terraform.workspace}-eip-nat-a" }
}

resource "aws_eip" "nat_b" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = { Project = "${terraform.workspace}-eip-nat-b" }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = { Name = "${var.project_name}-${terraform.workspace}-nat-a" }
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = { Name = "${var.project_name}-${terraform.workspace}-nat-b" }
}

# ── ROUTE TABLES ────────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = { Name = "${var.project_name}-${terraform.workspace}-private-rt-a" }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  tags = { Name = "${var.project_name}-${terraform.workspace}-private-rt-b" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# ── SECURITY GROUPS ─────────────────────────────────────────────────────────────
resource "aws_security_group" "lambda_sg_upload" {
  name   = "${var.project_name}-${terraform.workspace}-upload-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
  }
}

resource "aws_security_group" "lambda_sg_crop" {
  name   = "${var.project_name}-${terraform.workspace}-crop-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
  }
}

resource "aws_security_group" "sqs_endpoint_sg" {
  name        = "${var.project_name}-${terraform.workspace}-sqs-vpce-sg"
  description = "Permite trafico HTTPS hacia el endpoint de SQS desde las Lambdas"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg_upload.id, aws_security_group.lambda_sg_crop.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${terraform.workspace}-sqs-vpce-sg" }
}

resource "aws_security_group_rule" "upload_to_sqs" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_sg_upload.id
  source_security_group_id = aws_security_group.sqs_endpoint_sg.id
}

resource "aws_security_group_rule" "crop_to_sqs" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_sg_crop.id
  source_security_group_id = aws_security_group.sqs_endpoint_sg.id
}

# ── VPC ENDPOINTS ───────────────────────────────────────────────────────────────
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private_a.id, aws_route_table.private_b.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = ["${var.bucket_arn}/*"]
      Principal = "*"
    }]
  })
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.sqs_endpoint_sg.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-${terraform.workspace}-sqs-interface" }
}
