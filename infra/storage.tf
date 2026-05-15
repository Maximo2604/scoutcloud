resource "aws_ebs_volume" "game_data" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  tags = {
    Name    = "scoutcloud-game-data"
    Project = "scoutcloud"
  }
}

resource "aws_volume_attachment" "game_data_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.game_data.id
  instance_id = aws_instance.web.id
}

output "ebs_volume_id" {
  value = aws_ebs_volume.game_data.id
}
resource "aws_ami_from_instance" "web_golden" {
  name               = "scoutcloud-web-golden-v1"
  source_instance_id = aws_instance.web.id
  tags = {
    Name    = "scoutcloud-web-golden-v1"
    Project = "scoutcloud"
    Version = "1"
  }
}

output "ami_id" {
  value = aws_ami_from_instance.web_golden.id
}
