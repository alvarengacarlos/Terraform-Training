resource "aws_ssm_parameter" "database_root_password" {
  name  = "/${var.environment}/air-chain/database/root-password"
  type  = "SecureString"
  value = var.database_root_user_password
}

resource "aws_ssm_parameter" "database_endpoint" {
  name  = "/${var.environment}/air-chain/database/endpoint"
  type  = "String"
  value = aws_db_instance.database_server.endpoint
}
