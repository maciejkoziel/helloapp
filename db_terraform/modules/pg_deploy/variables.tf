variable "instance_role" {
  type = string
}
variable "instance_region" {
  type = string
}

variable "secondary_region" {
  type = string
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_amis" {
  default = {
    eu-central-1 = "ami-047e03b8591f2d48a" #AWS Linux
  eu-west-2 = "ami-074771aa49ab046e7" }    #AWS Linux
}

variable "cidr_block" {
  default = {
    eu-west-2 = "10.0.0.0/16"
  eu-central-1 = "10.1.0.0/16" }
}

variable "aws_availability_zone" {
  default = {
    eu-west-2 = "eu-west-2a"
  eu-central-1 = "eu-central-1a" }
}
