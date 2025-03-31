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

variable instance_type {
  default = "t3.nano"
}

resource random_string "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_instance" "instance" {
  ami           = data.aws_ami.amazon2.id
  instance_type = "${var.instance_type}"
  key_name      = aws_key_pair.key.key_name

  tags = {
    Name = "exampletf-${random_string.suffix.result}"
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "key" {
  key_name   = "exampletf-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "null_resource" "remote_exec_example" {
  triggers = {
    instance_id = aws_instance.instance.id
    public_ip   = aws_instance.instance.public_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.instance.public_ip
      user        = "ec2-user"
      private_key = tls_private_key.my_key.private_key_pem
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
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}

output "public_key" {
  value = tls_private_key.key.public_key_openssh
}