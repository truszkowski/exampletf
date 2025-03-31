terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

provider "tls" {}

data "aws_ami" "amazon2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

data "aws_availability_zones" "available" {}

variable instance_type {
  default = "t3.nano"
}

resource random_string "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_instance" "instance" {
  ami                         = data.aws_ami.amazon2.id
  instance_type               = "${var.instance_type}"
  key_name                    = aws_key_pair.aws-key.key_name
  subnet_id                   = aws_subnet.exampletf-subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true

  tags = {
    Name = "exampletf-${random_string.suffix.result}"
  }
}

resource "tls_private_key" "tls-key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "aws-key" {
  key_name   = "exampletf-key"
  public_key = tls_private_key.tls-key.public_key_openssh
}

resource "aws_vpc" "exampletf-vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "exampletf-vpc"
  }
}

resource "aws_subnet" "exampletf-subnet" {
  vpc_id                  = aws_vpc.exampletf-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "exampletf-subnet"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.exampletf-vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.exampletf-vpc.id

  tags = {
    Name = "exampletf-igw"
  }
}

resource "aws_route_table" "exampletf-rt" {
  vpc_id = aws_vpc.exampletf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "exampletf-route-table"
  }
}

resource "aws_route_table_association" "exampletf-assoc" {
  subnet_id      = aws_subnet.exampletf-subnet.id
  route_table_id = aws_route_table.exampletf-rt.id
}

resource "null_resource" "remote_exec_example" {
  triggers = {
    instance_id = aws_instance.instance.id
    public_ip   = aws_instance.instance.public_ip
  }

  depends_on = [aws_instance.instance]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.instance.public_ip
      user        = "ec2-user"
      private_key = tls_private_key.tls-key.private_key_pem
    }

    inline = [
      "echo 'hello EC2'",
      "hostname",
	  "uname -a"
    ]
  }
}

output public_ip {
  value = aws_instance.instance.public_ip
}

output public_dns {
  value = aws_instance.instance.public_dns
}

output "private_key" {
  value     = tls_private_key.tls-key.private_key_pem
  sensitive = true
}

output "public_key" {
  value = tls_private_key.tls-key.public_key_openssh
}