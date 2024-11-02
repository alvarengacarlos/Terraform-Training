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
## Bucket
##
resource "aws_s3_bucket" "files" {
  bucket = "${var.project_name}-files"
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.files.id

  topic {
    events = [
      "s3:ObjectCreated:Put",
      "s3:ObjectCreated:Post",
      "s3:ObjectRemoved:Delete"
    ]
    topic_arn = aws_sns_topic.adm_notifier.arn
  }
}

##
## SNS
##
resource "aws_sns_topic" "adm_notifier" {
  name = "${var.project_name}-adm-notifier"
  policy = data.aws_iam_policy_document.allow_s3_publish.json

}

data "aws_iam_policy_document" "allow_s3_publish" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["s3.amazonaws.com"]
      type = "Service"
    }
    actions = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:${var.project_name}-adm-notifier"]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [aws_s3_bucket.files.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [local.account_id]
    }
  }
}

resource "aws_sns_topic_subscription" "adm_notifier_subscription" {
  topic_arn = aws_sns_topic.adm_notifier.arn
  protocol  = "email"
  endpoint  = var.adm_email_addr
}