module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

module "network" {
  source             = "./modules/network"
  instance_count     = var.instance_count
  instance_type      = var.instance_type
  key_name           = var.key_name
  security_group_ids = [module.security.security_ext]
  name_prefix        = var.name_prefix
  environment        = var.environment
  tags               = var.tags
}