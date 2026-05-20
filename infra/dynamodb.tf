resource "aws_dynamodb_table" "live_scores" {
  name         = "scoutcloud-live-scores"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "game_id"

  attribute {
    name = "game_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = { Name = "scoutcloud-live-scores", Project = "scoutcloud" }
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.live_scores.name
}
