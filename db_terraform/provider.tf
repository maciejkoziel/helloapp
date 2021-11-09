terraform {
  required_providers {
    aws = ">= 3.35.0"
  }
  required_version = "1.0.10"
}

provider "aws" {
  region = local.primary_region
}

provider "aws" {
  alias  = "peer"
  region = local.secondary_region
}
