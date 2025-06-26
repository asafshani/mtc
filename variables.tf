variable "region_map" {
  type = map(string)
  default = {
    default     = "il-central-1"
    development = "us-east-1"
  }
}


variable "az_map" {
  type = map(string)
  default = {
    default     = "il-central-1a"
    development = "us-east-1a"
  }
}




variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "enviornment for deployment"
  default     = "dev"
}

variable "vpc_name" {
  type    = string
  default = "demo_vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  default = {
    "private_subnet_1" = 1
    "private_subnet_2" = 2
    "private_subnet_3" = 3
  }
}

variable "public_subnets" {
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
    "public_subnet_3" = 3
  }
}

variable "variables_sub_cidr" {
  description = "CIDR block for the variables subnet"
  type        = string
  default     = "10.0.202.0/24"
}

variable "variables_sub_az" {
  description = "Availablity zone used variables subnet"
  type        = string
  default     = "us-east-1a"
}

variable "variables_sub_auto_ip" {
  description = "set automatic IP assignment for variables subnet"
  type        = bool
  default     = true
}


