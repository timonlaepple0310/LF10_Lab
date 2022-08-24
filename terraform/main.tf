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
  region  = "eu-central-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-03f87e9ce1bec353f"
  instance_type = "t2.micro"

  tags = {
    Name = "Test Merver"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

provisioner "file" {
source      = "../ansible"
destination = "/home/ec2-user"

connection {
  type        = "ssh"
  host        = aws_instance.app_server
  user        = "ubuntu"
  private_key = tls_private_key.rsa.private_key_pem
  insecure    = true
}
}