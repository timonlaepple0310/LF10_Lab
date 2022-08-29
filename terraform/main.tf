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

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "aws_iam_policy_document" "lambda_assume_role_policy"{
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-lambdaRole-waf"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "archive_file" "python_lambda_package" {
  type = "zip"
  source_file = "../src/handler.py"
  output_path = "handler.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name = "write-sqs-data"
  filename      = "handler.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.6"
  handler       = "handler.lambda_handler"
  timeout       = 10
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.queue.arn
  enabled          = true
  function_name    = aws_lambda_function.lambda.arn
  batch_size       = 1
}

resource "aws_sqs_queue" "queue" {
  name                      = "lf10queue"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_s3_bucket" "bucket" {
  bucket = "fileuploadprodlf10"
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_cors_configuration" "bucket-configuration" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-03f87e9ce1bec353f"
  instance_type = "t2.micro"
  key_name      = "deployer-key"
  vpc_security_group_ids = [aws_security_group.main.id]
  associate_public_ip_address = true

  provisioner "file" {
    source = "../src/index.html"
    destination = "/home/ubuntu/index.html"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.rsa.private_key_pem
      host        = aws_instance.app_server.public_dns
    }
  }

  user_data = <<-EOF
                #!/bin/bash
                echo "*** Installing apache2"
                sudo apt update -y
                sudo apt install apache2 -y
                echo "*** Completed Installing apache2 - starting now"
                sudo service apache2 start
                sudo mv /home/ubuntu/index.html /var/www/html/index.html
                EOF

  tags = {
    Name = "Test Merver"
  }
}

resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress                = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    },
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    }
  ]
}
