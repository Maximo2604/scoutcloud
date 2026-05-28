resource "aws_ebs_volume" "game_data" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  tags = {
    Name    = "scoutcloud-game-data"
    Project = "scoutcloud"
  }
}

output "ebs_volume_id" {
  value = aws_ebs_volume.game_data.id
}
