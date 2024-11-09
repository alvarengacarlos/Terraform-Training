terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

##
## Lambda
##
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "index.mjs"
  output_path = "lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda" {
  function_name = "${var.project_name}-lambda"
  role          = aws_iam_role.lambda_role.arn
  environment {
    variables = {
      DB_URL = "mysql://user:userpw@anyhost:5432/hw_db"
    }
  }
  ephemeral_storage {
    size = 1024
  }
  filename                       = "lambda.zip"
  handler                        = "index.handler"
  //TODO: Uncomment below line when unreserved account concurrency be increase
  //reserved_concurrent_executions = 10
  runtime                        = "nodejs20.x"
  timeout                        = 5
}

resource "aws_lambda_alias" "lambda_alias" {
  name             = "dev"
  description      = "Used to define the development environment"
  function_name    = aws_lambda_function.lambda.function_name
  function_version = aws_lambda_function.lambda.version
}

resource "aws_lambda_function_url" "lambda_function_url" {
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
    allow_methods = ["GET"]
  }
}
