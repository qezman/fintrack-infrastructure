data "aws_caller_identity" "current" {}


module "vpc" {
  source             = "../../modules/vpc"
  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "eks" {
  source             = "../../modules/eks"
  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}

module "rds" {
  source                     = "../../modules/rds"
  project                    = var.project
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  db_username                = var.db_username
  db_password                = var.db_password
}

module "s3" {
  source         = "../../modules/s3"
  project        = var.project
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id
}

module "iam" {
  source              = "../../modules/iam"
  project             = var.project
  environment         = var.environment
  aws_account_id      = data.aws_caller_identity.current.account_id
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  receipts_bucket_arn = module.s3.bucket_arn
}

module "dns" {
  source       = "../../modules/dns"
  project      = var.project
  environment  = var.environment
  domain_name  = var.domain_name
  subdomain    = var.subdomain
  elb_dns_name = var.elb_dns_name
  elb_zone_id  = var.elb_zone_id
}

module "external_secrets" {
  source            = "../../modules/external-secrets"
  project           = var.project
  environment       = var.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  database_url      = var.database_url
  jwt_secret        = var.jwt_secret
}
