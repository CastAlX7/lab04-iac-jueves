variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "processor-image"
}

variable "vpc_cidr" {
  description = "IPs rango para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "priv_subnet_a_cidr" {
  type        = string
  default     = "10.0.11.0/24"
}

variable "priv_subnet_b_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "alert_email" {
  description = "Email para recibir alertas de la DLQ"
  type        = string
}