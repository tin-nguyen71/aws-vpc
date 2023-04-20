locals {
  network_assume_role = var.network_assume_role == null || var.network_assume_role == "" ? var.assume_role : var.network_assume_role
}

provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = var.assume_role
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "network"

  assume_role {
    role_arn = local.network_assume_role
  }
}
