provider "aws" {
  region = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Owner = "Marc-Steffen Kaesz"
    }
  }
}

data "aws_eks_cluster" "app_cluster" {
  name = module.wandb_infra.cluster_id
}

data "aws_eks_cluster_auth" "app_cluster" {
  name = module.wandb_infra.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.app_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.app_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.app_cluster.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.app_cluster.name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.app_cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.app_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.app_cluster.token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.app_cluster.name]
      command     = "aws"
    }
  }
}

locals{
  oidc_envs = {
    "OIDC_ISSUER"                   = "https://${aws_cognito_user_pool.wandb.endpoint}/"
    "OIDC_CLIENT_ID"                = aws_cognito_user_pool_client.userpool_client.id
    "OIDC_AUTH_METHOD"              = "pkce"
    "OIDC_SECRET"                   = aws_cognito_user_pool_client.userpool_client.client_secret
    "GORILLA_USE_IDENTIFIER_CLAIMS" = true
  }
  env_vars = merge(
    local.oidc_envs,
    var.other_wandb_env,
  )
}

module "wandb_infra" {
  source  = "wandb/wandb/aws"
  version = "4.10.2"
  
  license = var.wandb_license

  namespace            = var.namespace
  public_access        = true
  external_dns         = true
  enable_dummy_dns     = true
  enable_operator_alb  = true
  custom_domain_filter = var.domain_name
  
  deletion_protection = false

  database_instance_class      = var.database_instance_class
  database_engine_version      = var.database_engine_version
  database_snapshot_identifier = var.database_snapshot_identifier
  database_sort_buffer_size    = var.database_sort_buffer_size

  allowed_inbound_cidr      = var.allowed_inbound_cidr
  allowed_inbound_ipv6_cidr = ["::/0"]

  eks_cluster_version            = "1.25"
  kubernetes_public_access       = true
  kubernetes_public_access_cidrs = ["0.0.0.0/0"]

  domain_name = var.domain_name
  zone_id     = var.zone_id
  subdomain   = var.subdomain

  bucket_name        = var.bucket_name
  bucket_kms_key_arn = var.bucket_kms_key_arn
  use_internal_queue = true

  other_wandb_env = local.env_vars
}

output "url" {
  value = module.wandb_infra.url
}
