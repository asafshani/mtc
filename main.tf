# Configure the AWS Provider
provider "aws" {
  region                   = lookup(var.region_map, terraform.workspace, "il-central-1")
  shared_credentials_files = ["/home/asaf/.aws/credentials"]
  default_tags {

    tags = {
      Environment = terraform.workspace
      Owner       = "Asaf"
      Provisioned = "Terraform"
    }
  }
}


locals {
  team        = "api_mgmt_dev"
  application = "corp_api"
  #server_name = "ec2-${var.environment}-api-${var.variables_sub_az}"
  server_name = "ec2-${var.environment}-api-${lookup(var.az_map, terraform.workspace, "il-central-1")}"
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "demo_environment"
    Terraform   = "true"
    Region      = lookup(var.region_map, terraform.workspace, "il-central-1")
  }
}

#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = element(data.aws_availability_zones.available.names, each.value - 1)
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each   = var.public_subnets
  vpc_id     = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = element(data.aws_availability_zones.available.names, each.value - 1)
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  # route {
  #   cidr_block = "0.0.0.0/0"
  #   gateway_id = aws_internet_gateway.internet_gateway.id
  #   #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  # }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
#  route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.internet_gateway.id
#     #   nat_gateway_id = aws_nat_gateway.nat_gateway.id
#   }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

#Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  depends_on = [
    aws_route_table.public_route_table,
    aws_route_table.private_route_table
  ]
  tags = {
    Name = "demo_igw"
  }
}

#Create EIP for NAT Gateway
#resource "aws_eip" "nat_gateway_eip" {
# domain     = "vpc"
# depends_on = [aws_internet_gateway.internet_gateway]
# tags = {
#  Name = "demo_igw_eip"
#}
#}

#Create NAT Gateway
#resource "aws_nat_gateway" "nat_gateway" {
#  depends_on    = [aws_subnet.public_subnets]
#  allocation_id = aws_eip.nat_gateway_eip.id
#  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
#  tags = {
#    Name = "demo_nat_gateway"
#  }
#}

resource "aws_instance" "ubuntu_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups             = [aws_security_group.vpc-ping.id, aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generated.private_key_pem
    host        = self.public_ip
  }

  tags = {
    Name = "Ubuntu EC2 Server"
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
  provisioner "local-exec" {
    command = "chmod 600 ${local_file.private_key_pem.filename}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp",
      "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
      "sudo sh /tmp/assets/setup-web.sh",
    ]
  }

}






resource "aws_s3_bucket" "my-new-s3-bucket" {
  bucket = "asaf-${random_id.randomness.hex}"
  tags = {
    Name    = "My S3 bucket"
    Purpuse = "Intro to resource blocks lab"
  }
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.my-new-s3-bucket.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "my-new-s3-bucket_acl" {
  bucket     = aws_s3_bucket.my-new-s3-bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.ownership]
}

resource "aws_security_group" "my-new-security-group" {
  name        = "web-server-inbound"
  description = "Allow inbound traffic on tcp/443"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/2"]
  }

  tags = {
    Name    = "web_server_inbound"
    Purpose = "Intro to resource blocks lab"
  }
}

resource "random_id" "randomness" {
  byte_length = 16
}

resource "aws_subnet" "variable-subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.variables_sub_cidr
  availability_zone       = lookup(var.az_map, terraform.workspace, "il-central-1")
  map_public_ip_on_launch = var.variables_sub_auto_ip
}

# Terraform Data Block - Lookup Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

# module "subnet_addrs" {
#   source  = "hashicorp/subnets/cidr"
#   version = "1.0.0"

#   base_cidr_block = "10.0.0.0/22"
#   networks = [
#     {
#       name     = "module_network_a"
#       new_bits = 2
#     },
#     {
#       name     = "module_network_b"
#       new_bits = 2
#     },
#   ]
# }

# output "subnet_addrs" {
#   value = module.subnet_addrs.network_cidr_blocks
# }


resource "tls_private_key" "generated" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey-${terraform.workspace}"
  public_key = tls_private_key.generated.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]
  }
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "MyAWSKey.pem"
}

resource "aws_security_group" "ingress-ssh" {
  name        = "allow-all-ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc-ping" {
  name        = "vpc-ping"
  vpc_id      = aws_vpc.vpc.id
  description = "ICMP for Ping Access"
  ingress {
    description = "Allow ICMP Traffic"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group - Web Traffic
resource "aws_security_group" "vpc-web" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all ip and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_instance" "web_server" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t3.micro"
#   subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
#   security_groups             = [aws_security_group.vpc-ping.id, aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.generated.key_name
#   connection {
#     user        = "ubuntu"
#     private_key = tls_private_key.generated.private_key_pem
#     host        = self.public_ip
#   }

#   tags = {
#     Name = "WEB EC2 Server"
#   }

#   lifecycle {
#     ignore_changes = [security_groups]
#   }
#   provisioner "local-exec" {
#     command = "chmod 600 ${local_file.private_key_pem.filename}"
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "sudo rm -rf /tmp",
#       "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
#       "sudo sh /tmp/assets/setup-web.sh",
#     ]
#   }

# }

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}
