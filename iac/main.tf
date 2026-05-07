module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  alert_email  = var.alert_email
}

module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  public_subnet_a_cidr = var.public_subnet_a_cidr
  public_subnet_b_cidr = var.public_subnet_b_cidr
  priv_subnet_a_cidr   = var.priv_subnet_a_cidr
  priv_subnet_b_cidr   = var.priv_subnet_b_cidr
  bucket_arn           = module.storage.bucket_arn
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  bucket_arn   = module.storage.bucket_arn
  queue_arn    = module.storage.queue_arn
}

module "compute" {
  source = "./modules/compute"

  project_name        = var.project_name
  aws_region          = var.aws_region
  bucket_id           = module.storage.bucket_id
  queue_arn           = module.storage.queue_arn
  private_subnet_a_id = module.network.private_subnet_a_id
  private_subnet_b_id = module.network.private_subnet_b_id
  upload_sg_id        = module.network.upload_sg_id
  crop_sg_id          = module.network.crop_sg_id
  upload_role_arn     = module.iam.upload_role_arn
  crop_role_arn       = module.iam.crop_role_arn
}
