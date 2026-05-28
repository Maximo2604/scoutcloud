# ec2.tf — ScoutCloud web server
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
  vpc_id      = module.network.vpc_id
  description = "Security group for ScoutCloud web server"

  ingress {
    description     = "HTTP"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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
  public_key = var.ec2_public_key
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  availability_zone      = "us-east-1a"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = module.network.private_subnet_ids[0]

  user_data = base64encode(<<-USEREOF
#!/bin/bash
yum update -y
yum install -y git python3 python3-pip libpq-devel curl --skip-broken
pip3 install gunicorn flask --ignore-installed
mkdir -p /opt/scoutcloud/app
cat > /opt/scoutcloud/app/app.py << APPEOF
from flask import Flask, jsonify
from datetime import datetime
import urllib.request

app = Flask(__name__)

def get_instance_id():
    try:
        return urllib.request.urlopen("http://169.254.169.254/latest/meta-data/instance-id", timeout=2).read().decode()
    except:
        return "local-dev"

GAMES = [
    {"home": "Boston Celtics", "away": "Miami Heat", "home_score": 87, "away_score": 82, "quarter": "Q3 8:42"},
    {"home": "LA Lakers", "away": "Golden State Warriors", "home_score": 104, "away_score": 98, "quarter": "Q4 2:15"},
    {"home": "Chicago Bulls", "away": "New York Knicks", "home_score": 61, "away_score": 67, "quarter": "Q2 4:33"},
]

@app.route("/")
def index():
    instance_id = get_instance_id()
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    games_html = ""
    for g in GAMES:
        games_html += f"""
        <div class="game-card">
            <div class="quarter">{g["quarter"]}</div>
            <div class="matchup">
                <div class="team"><span class="name">{g["away"]}</span><span class="score">{g["away_score"]}</span></div>
                <div class="vs">@</div>
                <div class="team"><span class="name">{g["home"]}</span><span class="score">{g["home_score"]}</span></div>
            </div>
        </div>"""
    return f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>ScoutCloud</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:-apple-system,sans-serif;background:#0a0e1a;color:#e2e8f0;min-height:100vh}}
header{{background:#111827;border-bottom:1px solid #1e293b;padding:1rem 2rem;display:flex;justify-content:space-between;align-items:center}}
.logo{{font-size:1.4rem;font-weight:700;color:#f97316}}.logo span{{color:#94a3b8;font-weight:400}}
.badge{{background:#052e16;color:#4ade80;border:1px solid #166534;padding:.3rem .8rem;border-radius:999px;font-size:.75rem;font-weight:600}}
.container{{max-width:960px;margin:0 auto;padding:2rem}}
.meta{{display:flex;gap:2rem;background:#111827;border:1px solid #1e293b;border-radius:12px;padding:1.2rem 1.5rem;margin-bottom:2rem}}
.meta-item{{display:flex;flex-direction:column;gap:.2rem}}
.meta-label{{font-size:.7rem;text-transform:uppercase;color:#64748b;letter-spacing:.08em}}
.meta-value{{font-size:.9rem;font-weight:600;font-family:monospace}}
h2{{font-size:.85rem;text-transform:uppercase;letter-spacing:.1em;color:#64748b;margin-bottom:1rem}}
.game-card{{background:#111827;border:1px solid #1e293b;border-radius:12px;padding:1.2rem 1.5rem;margin-bottom:1rem}}
.quarter{{font-size:.75rem;color:#f97316;font-weight:700;text-transform:uppercase;margin-bottom:.8rem}}
.matchup{{display:flex;align-items:center;gap:1rem}}
.team{{display:flex;justify-content:space-between;align-items:center;flex:1;gap:1rem}}
.score{{font-size:1.8rem;font-weight:700;color:#f1f5f9}}
.vs{{color:#475569;font-size:.8rem}}
footer{{text-align:center;color:#334155;font-size:.75rem;margin-top:3rem;padding-bottom:2rem}}
</style></head>
<body>
<header><div class="logo">Scout<span>Cloud</span></div><div class="badge">&#9679; System Operational</div></header>
<div class="container">
<div class="meta">
<div class="meta-item"><span class="meta-label">Instance ID</span><span class="meta-value">{instance_id}</span></div>
<div class="meta-item"><span class="meta-label">Server Time</span><span class="meta-value">{now}</span></div>
<div class="meta-item"><span class="meta-label">Environment</span><span class="meta-value">production</span></div>
<div class="meta-item"><span class="meta-label">Version</span><span class="meta-value">1.0.0</span></div>
</div>
<h2>Live Games</h2>{games_html}
</div>
<footer>ScoutCloud NBA Intelligence Platform</footer>
</body></html>"""

@app.route("/health")
def health():
    return jsonify(status="ok", instance_id=get_instance_id())

if __name__ == "__main__":
    app.run()
APPEOF
cat > /etc/systemd/system/scoutcloud.service << SVCEOF
[Unit]
Description=ScoutCloud NBA Intelligence Platform
After=network-online.target
[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/scoutcloud/app
ExecStart=/usr/local/bin/gunicorn app:app -b 0.0.0.0:8080 -w 2
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVCEOF
chown -R ec2-user:ec2-user /opt/scoutcloud
systemctl daemon-reload
systemctl enable scoutcloud
systemctl start scoutcloud
USEREOF
  )

  tags = {
    Name        = "scoutcloud-web"
    Project     = "scoutcloud"
    Environment = "dev"
    Chapter     = "3-challenge"
  }
}

output "web_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of the ScoutCloud web server"
}
resource "aws_iam_role" "ec2_ssm" {
  name = "scoutcloud-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "scoutcloud-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}
