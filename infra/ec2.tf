# ec2.tf — ScoutCloud web server (recreated from Terraform)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_security_group" "web" {
  name        = "scoutcloud-web-sg"
  description = "Security group for ScoutCloud web server"

  ingress {
    description = "HTTP - replaced by ALB-only in Chapter 5"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "scoutcloud-web-sg", Project = "scoutcloud" }
}

resource "aws_key_pair" "deployer" {
  key_name   = "scoutcloud-key"
  public_key = file("~/.ssh/scoutcloud-key.pem.pub")
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(<<-USEREOF
#!/bin/bash
yum update -y
yum install -y git python3 python3-pip libpq-devel curl
git clone https://github.com/${var.github_username}/scoutcloud.git /opt/scoutcloud
chown -R ec2-user:ec2-user /opt/scoutcloud
cd /opt/scoutcloud/src/app && pip3 install -r requirements.txt
cat > /etc/systemd/system/scoutcloud.service <<'SVCEOF'
[Unit]
Description=ScoutCloud NBA Intelligence Platform
After=network-online.target
[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/scoutcloud/src/app
Environment="DATABASE_URL=placeholder"
Environment="DYNAMODB_TABLE=placeholder"
Environment="AWS_REGION=us-east-1"
ExecStart=/usr/local/bin/gunicorn app:app -b 0.0.0.0:8080 -w 2
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable scoutcloud
systemctl start scoutcloud
USEREOF
  )

  tags = {
    Name        = "scoutcloud-web"
    Project     = "scoutcloud"
    Environment = "dev"
    Chapter     = "3"
  }
}

output "web_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP — use until scoutcloud.dev is live in Chapter 5"
}
