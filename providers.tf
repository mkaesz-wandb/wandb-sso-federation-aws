provider "aws" {
  region = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Owner = "Marc-Steffen Kaesz"
    }
  }
}

terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = ">= 1.0.0" # Refer to docs for latest version
    }
  }
}

provider "auth0" {}



