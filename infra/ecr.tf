resource "aws_ecr_repository" "score_fetcher" {
  name                 = "scoutcloud/score-fetcher"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "scoutcloud-score-fetcher", Project = "scoutcloud" }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.score_fetcher.repository_url
}
