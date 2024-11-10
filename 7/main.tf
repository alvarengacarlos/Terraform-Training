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

data "aws_caller_identity" "current_caller" {}

locals {
  account_id = data.aws_caller_identity.current_caller.account_id
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

resource "aws_iam_policy" "lambda_iam_policy" {
  name = "${var.project_name}-lambda-iam-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement : [
      {
        Effect : "Allow",
        Action : "sns:Publish"
        Resource : aws_sns_topic.adm_notifier.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda" {
  function_name = "${var.project_name}-lambda"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda.zip"
  handler       = "index.handler"
  //TODO: Uncomment below line when unreserved account concurrency be increase
  //reserved_concurrent_executions = 10
  runtime = "nodejs20.x"
  timeout = 5
}

resource "aws_lambda_function_event_invoke_config" "lambda_event_invoke_config" {
  function_name = aws_lambda_function.lambda.function_name
  destination_config {
    on_failure {
      destination = aws_sns_topic.adm_notifier.arn
    }
    on_success {
      destination = aws_sns_topic.adm_notifier.arn
    }
  }
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 1
}

##
## SNS
##
resource "aws_sns_topic" "adm_notifier" {
  name = "${var.project_name}-adm-notifier"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Resource = "arn:aws:sns:*:*:${var.project_name}-adm-notifier"
        Action   = ["SNS:Publish"]
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_lambda_function.lambda.arn
          }
          StringEquals = {
            "aws:SourceAccount" : local.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "adm_notifier_subscription" {
  topic_arn = aws_sns_topic.adm_notifier.arn
  protocol  = "email"
  endpoint  = var.adm_email_addr
}
