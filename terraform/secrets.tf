resource "random_password" "mongodb_admin" {
  length = 24
  special = false
}

resource "random_password" "jwt_secret" {
  length = 32
  special = false
}

resource "aws_secretsmanager_secret" "mongodb_credentials" {
  name = "${var.project_name}/mongodb-credentials"
  description = "MongoDB admin credentials for the wiz-exercise application"

  tags = {
    Name = "${var.project_name}-mongodb-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "mongodb_credentials" {
  secret_id = aws_secretsmanager_secret.mongodb_credentials.id

  secret_string = jsonencode({
    username = "wizadmin"
    password = random_password.mongodb_admin.result
    host = aws_instance.mongodb.private_ip
    port = "27017"
    uri = "mongodb://wizadmin:${random_password.mongodb_admin.result}@${aws_instance.mongodb.private_ip}:27017/go-mongodb?authSource=admin"
  })
}

resource "aws_secretsmanager_secret" "jwt_secret_key" {
  name = "${var.project_name}/jwt-secret-key"
  description = "JWT signing key for the Tasky application"

  tags = {
    Name = "${var.project_name}-jwt-secret-key"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret_key" {
  secret_id = aws_secretsmanager_secret.jwt_secret_key.id
  secret_string = random_password.jwt_secret.result
}
