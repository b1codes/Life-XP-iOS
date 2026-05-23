resource "aws_dynamodb_table" "wellness_table" {
  name         = "${var.app_name}-${var.environment}-wellness"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Enforce KMS encryption at rest (default aws/dynamodb key is cost-free)
  server_side_encryption {
    enabled     = true
    kms_key_arn = null
  }

  # Enable Point-in-time recovery to secure against accidental writes/deletes
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.app_name}-${var.environment}-wellness"
  }
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.wellness_table.name
  description = "The name of the generated DynamoDB single-table database"
}

output "dynamodb_table_arn" {
  value       = aws_dynamodb_table.wellness_table.arn
  description = "The ARN of the DynamoDB single-table database"
}
