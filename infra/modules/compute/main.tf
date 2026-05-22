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
    tags          = { Name = "${var.project}-web", Project = var.project }
  }
}


output "launch_template_id" { value = aws_launch_template.web.id }
