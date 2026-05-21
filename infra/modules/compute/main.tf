variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "project" {
  type    = string
  default = "scoutcloud"
}

resource "aws_launch_template" "web" {
  name_prefix            = "${var.project}-web-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y && yum install -y httpd
    systemctl start httpd && systemctl enable httpd
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "<h1>ScoutCloud</h1><p>$INSTANCE_ID</p>" > /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project}-web", Project = var.project }
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.project}-asg"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}

output "asg_name" { value = aws_autoscaling_group.web.name }
