terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "elian-terraform-state"
    key    = "HW/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "elian-terraform-state"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_secretsmanager_secret" "pf_secret" {
  name = "pf_secret"
}

resource "aws_secretsmanager_secret_version" "pf_secret_version" {
  secret_id     = aws_secretsmanager_secret.pf_secret.id
  secret_string = jsonencode({
    username = "User1234",
    password = "Pass1234",
  })
}

resource "aws_kms_key" "pf_key" {
  description = "PF KMS key"
}

resource "aws_ssm_parameter" "pf_ps_secret" {
  name      = "/pf-app/pf-secret"
  type      = "SecureString"
  value     = "Pass123"
  key_id    = aws_kms_key.pf_key.id
}

resource "aws_lambda_function" "lambda_ps" {
  filename = "funcion.zip"
  function_name = "ps_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  environment {
    variables = {
      MY_SECRET = aws_ssm_parameter.pf_ps_secret.value
    }
  }
}

resource "aws_lambda_function" "lambda_sm" {
  filename = "funcion.zip"
  function_name = "sm_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  environment {
    variables = {
      MY_SECRET = aws_secretsmanager_secret_version.pf_secret_version.secret_string
    }
  }
}

