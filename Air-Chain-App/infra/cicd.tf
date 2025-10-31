resource "aws_s3_bucket" "pipeline_bucket" {
  bucket        = "air-chain-pipeline-bucket"
  force_destroy = true
  tags = {
    Environment = var.environment
  }
}

#
# Code Build
#
resource "aws_cloudwatch_log_group" "codebuild_cloudwatch_log_group" {
  name              = "air-chain-codebuild-log-group"
  retention_in_days = 1
  tags = {
    Environment = var.environment
  }
}

resource "aws_codebuild_source_credential" "codebuild_source_credential" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_personal_access_token
}

resource "aws_iam_role" "codebuild_service_role" {
  name = "air-chain-codebuild-service-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "codebuild.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "air-chain-codebuild-policy"
  role = aws_iam_role.codebuild_service_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "codeconnections:GetConnectionToken",
          "codeconnections:GetConnection",
          "codeconnections:UseConnection"
        ]
        Resource : [
          "arn:aws:codeconnections:${var.aws_region}:${local.account_id}:connection/*"
        ]
      },
      {
        Effect : "Allow"
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource : [
          "${aws_cloudwatch_log_group.codebuild_cloudwatch_log_group.arn}:*"
        ],
      },
      {
        Effect : "Allow"
        Action : [
          "s3:PutObject",
        ]
        Resource : [
          "${aws_s3_bucket.pipeline_bucket.arn}/*"
        ]
      },
      {
        Effect : "Allow"
        Action : [
          "ssm:GetParameters",
        ]
        Resource : [
          aws_ssm_parameter.database_root_password.arn,
          aws_ssm_parameter.database_endpoint.arn
        ]
      },
      {
        Effect : "Allow"
        Action : [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource : [
          "arn:aws:kms:${var.aws_region}:${local.account_id}:key/*",
        ]
      }
    ]
  })
}

resource "aws_codebuild_project" "codebuild_project" {
  name         = "air-chain-codebuild-project"
  service_role = aws_iam_role.codebuild_service_role.arn
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "docker:dind"
    type         = "LINUX_CONTAINER"
  }
  source {
    buildspec = "buildspec.yml"
    type      = "GITHUB"
    location  = "https://github.com/alvarengacarlos/Air-Chain-App"
  }
  source_version = var.environment == "dev" ? "develop" : "master"
  artifacts {
    location       = aws_s3_bucket.pipeline_bucket.bucket
    namespace_type = "NONE"
    packaging      = "NONE"
    type           = "S3"
  }
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_cloudwatch_log_group.name
      status     = "ENABLED"
    }
  }
  tags = {
    Environment = var.environment
  }
}

#
# Code deploy
#
resource "aws_codedeploy_app" "frontend_codedeploy_app" {
  name             = "air-chain-frontend-codedeploy-app"
  compute_platform = "Server"
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role" "codedeploy_service_role" {
  name = "air-chain-codedeploy-service-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Effect : "Allow"
        Principal : {
          Service : "codedeploy.amazonaws.com"
        }
        Action : "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy_for_codedeploy_attachment" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_deployment_group" "frontend_codedeploy_deployment_group" {
  app_name              = aws_codedeploy_app.frontend_codedeploy_app.name
  deployment_group_name = "air-chain-frontend-codedeploy-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn
  alarm_configuration {
    enabled = false
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }
  ec2_tag_filter {
    key   = "Name"
    value = aws_instance.web_server.tags.Name
    type  = "KEY_AND_VALUE"
  }
  tags = {
    Environment = var.environment
  }
}

resource "aws_codedeploy_app" "backend_codedeploy_app" {
  name             = "air-chain-backend-codedeploy-app"
  compute_platform = "Server"
  tags = {
    Environment = var.environment
  }
}

resource "aws_codedeploy_deployment_group" "backend_codedeploy_deployment_group" {
  app_name              = aws_codedeploy_app.backend_codedeploy_app.name
  deployment_group_name = "air-chain-backend-codedeploy-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn
  alarm_configuration {
    enabled = false
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }
  ec2_tag_filter {
    key   = "Name"
    value = aws_instance.web_server.tags.Name
    type  = "KEY_AND_VALUE"
  }
  tags = {
    Environment = var.environment
  }
}
