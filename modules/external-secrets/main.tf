# AWS Secrets Manager secret storing backend credentials
resource "aws_secretsmanager_secret" "backend" {
  name        = "${var.project}-${var.environment}-backend-secrets"
  description = "FinTrack backend DATABASE_URL and JWT_SECRET"

  tags = {
    Name = "${var.project}-${var.environment}-backend-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id

  secret_string = jsonencode({
    DATABASE_URL = var.database_url
    JWT_SECRET   = var.jwt_secret
  })
}

# IRSA role for External Secrets Operator
resource "aws_iam_role" "external_secrets" {
  name = "${var.project}-${var.environment}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.environment}-external-secrets-role"
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "${var.project}-${var.environment}-external-secrets-policy"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.backend.arn
      }
    ]
  })
}
