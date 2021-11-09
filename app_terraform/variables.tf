data "terraform_remote_state" "db_infra" {
  backend = "local"

  config = {
    path = "../db_terraform/terraform.tfstate"
  }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

data "aws_vpc" "main" {
  id = data.terraform_remote_state.db_infra.outputs.primary_vpc_id
}

locals {
  primary_region = "eu-west-2"
}

variable "app_count" {
  type    = number
  default = 1
}

variable "appcontainer_port" {
  type    = number
  default = 5000
}

variable "helloapp_image_location" {
  type = string
}
