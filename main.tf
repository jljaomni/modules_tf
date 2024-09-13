provider "aws" {    
    region = "us-east-1"
    access_key = ""
    secret_key = ""
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "vpc" {
  source = "./module/vpc"  # Ruta relativa al módulo de la VPC

  # Parámetros requeridos por el módulo
  vpc_cidr_block     = "10.0.0.0/16"
  vpc_name           = "terraform"

  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                = ["us-east-1a", "us-east-1b"]
  

  tags = {
    Terraform = "true"
    Environment = "dev"
    company = "omnipro"
  }

}

