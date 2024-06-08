terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = ">= 1.0.0" # Refer to docs for latest version
    }
  }
}

provider "auth0" {}

locals {
  domain = module.wandb_infra.url
}

data "aws_region" "current" {}

resource "auth0_client" "wandb" {
  name                    = "mkaesz - SSO Test"
  description             = "SSO testing..."
  app_type                = "spa"
  oidc_conformant         = true
  callbacks               = ["https://${aws_cognito_user_pool_domain.wandb.id}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/idpresponse"]
  allowed_logout_urls     = ["${local.domain}/logout"]
  grant_types = [
    "authorization_code",
  ]
}

resource "auth0_client_credentials" "oidc_client_creds" {
  client_id = auth0_client.wandb.id
  authentication_method = "client_secret_post"
}

# This is the federated user.
resource "auth0_user" "user" {
  connection_name = "Username-Password-Authentication"
  name            = "Marc-Steffen Kaesz"
  email           = "mkaesz@wandb.com"
  email_verified  = true
  password        = "abc123$M"
}

resource "aws_cognito_user_pool" "wandb" {
  name                     = "wandb-pool"
  auto_verified_attributes = ["email"]
}

# Just a Cognito test user to test the Cognito/WandB integration without federation
# aws_cognito_user_pool_client.userpool_client.supported_identity_providers must include "COGNITO"
resource "aws_cognito_user" "wandb" {
  user_pool_id = aws_cognito_user_pool.wandb.id
  username     = "mkaesz"
  password     = "abc123$M"

  attributes = {
    email          = "mkaesz@wandb.com"
    email_verified = true
  }
}

resource "aws_cognito_user_pool_client" "userpool_client" {
  name                                 = "W and B Client"
  user_pool_id                         = aws_cognito_user_pool.wandb.id
  callback_urls                        = ["${local.domain}/oidc/callback"]
  logout_urls                          = ["${local.domain}/logout"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = [aws_cognito_identity_provider.auth0.provider_name]
  #supported_identity_providers         = ["COGNITO", aws_cognito_identity_provider.auth0.provider_name]
  generate_secret                      = true
}

resource "aws_cognito_identity_provider" "auth0" {
  user_pool_id  = aws_cognito_user_pool.wandb.id
  provider_name = "Auth0"
  provider_type = "OIDC"

  provider_details = {
    authorize_scopes          = "email profile openid"
    client_id                 = auth0_client.wandb.client_id
    client_secret             = auth0_client_credentials.oidc_client_creds.client_secret
    attributes_request_method = "GET"
    oidc_issuer               = "https://wandb-qa.auth0.com"
  }
  
  attribute_mapping = {
     email              = "email"
     username           = "sub"
     name               = "name"
     nickname           = "nickname"
     preferred_username = "nickname"
     email_verified     = "email_verified"
   }
 }

resource "aws_cognito_user_pool_domain" "wandb" {
  domain       = "wandb"
  user_pool_id = aws_cognito_user_pool.wandb.id
}

output "oidc_issuer_url" {
  value = "https://${aws_cognito_user_pool.wandb.endpoint}"
}

output "oidc_client_id" {
  value = aws_cognito_user_pool_client.userpool_client.id
} 

output "oidc_client_secret" {
  value = aws_cognito_user_pool_client.userpool_client.client_secret
  sensitive = true
}
