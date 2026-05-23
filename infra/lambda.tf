data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend"
  output_path = "${path.module}/backend_lambda.zip"
  excludes    = ["tests", ".pytest_cache", "__pycache__"]
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic execution role policy for CloudWatch logging
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Strict custom policy for single-table DynamoDB access (least privilege)
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.app_name}-${var.environment}-dynamodb-policy"
  description = "Allows Lambda read/write rights only to the specific wellness DynamoDB resource"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.wellness_table.arn,
          "${aws_dynamodb_table.wellness_table.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_lambda_function" "api_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "${var.app_name}-${var.environment}-api"
  role             = aws_iam_role.lambda_role.arn
  handler          = "app.main.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.wellness_table.name
      AWS_REGION     = var.aws_region
      APPLE_AUDIENCE = var.apple_audience
      AUTH0_DOMAIN   = var.auth0_domain
      AUTH0_AUDIENCE = var.auth0_audience
    }
  }
}

variable "apple_audience" {
  type        = string
  default     = "blc.Life-XP-iOS"
  description = "Bundle Identifier for Apple Sign In Audience validation"
}

variable "auth0_domain" {
  type        = string
  default     = ""
  description = "Auth0 Tenant Domain (e.g. your-tenant.us.auth0.com)"
}

variable "auth0_audience" {
  type        = string
  default     = ""
  description = "Auth0 API Identifier or Client ID"
}

output "lambda_function_name" {
  value       = aws_lambda_function.api_lambda.function_name
  description = "The name of the backend Lambda function"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.api_lambda.arn
  description = "The ARN of the backend Lambda function"
}
