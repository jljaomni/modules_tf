variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  type    = string
  default = "my-vpc"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

/* variable "availability_zones" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b"]
}
 */
variable "azs" {
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "nat_per_az" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {
    Environment = "production"
  }
}

variable "enable_nat_instance" {
  type    = bool
  default = false
}

variable "nat_instance_ami" {
  type    = string
  description = "AMI ID para la instancia NAT"
  default = null
}