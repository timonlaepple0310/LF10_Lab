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
  region  = "YOUR_REGION_HERE"
}

resource "aws_key_pair" "deployer" {
  key_name   = "YOUR_KEY_HERE"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_iam_role" "lambda_role" {
  name = "YOUR_IAM_ROLE_HERE"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sqs:*"]

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
  }

  statement {
    sid       = "AllowInvokingLambdas"
    effect    = "Allow"
    resources = ["arn:aws:lambda:YOUR_REGION_HERE*:function:*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = "AllObjectActions"
    effect    = "Allow"
    actions = ["s3:*Object"]
    resources = ["arn:aws:s3:::YOUR_BUCKET_HERE/*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "YOUR_POLICY_NAME_HERE"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "POLICY_ATTACHMENT" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "python_lambda_package" {
  type = "zip"
  source_file = "../src/handler/handler.py"
  output_path = "handler.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name = "YOUR_FUNCTION_NAME"
  filename      = "handler.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "handler.lambda_handler"
  timeout       = 10
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.queue.arn
  enabled          = true
  function_name    = aws_lambda_function.lambda.arn
  batch_size       = 10
}

resource "aws_sqs_queue" "queue" {
  name                      = "YOUR_QUEUE_NAME_HERE"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_s3_bucket" "bucket" {
  bucket = "YOUR_BUCKET_HERE"
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
  key_name      = "YOUR_KEY_NAME_HERE"
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