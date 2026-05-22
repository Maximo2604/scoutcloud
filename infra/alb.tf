resource "aws_launch_template" "web" {
  name_prefix            = "scoutcloud-web-"
  image_id               = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = "scoutcloud-key"
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
set -euo pipefail
yum update -y
yum install -y python3 python3-pip --skip-broken
pip3 install flask gunicorn --ignore-installed
mkdir -p /opt/scoutcloud

cat > /opt/scoutcloud/app.py <<APPEOF
from flask import Flask, jsonify
import socket

app = Flask(__name__)
HOST = socket.gethostname()

DEMO_GAMES = [
    {"home":"Knicks","away":"Celtics","score":"112-108","status":"Final"},
    {"home":"Lakers","away":"Warriors","score":"94-91","status":"Q4 4:12"},
    {"home":"Heat","away":"Bulls","score":"63-68","status":"Q3 0:48"},
]

DEMO_PLAYERS = [
    {"name":"Jalen Brunson","team":"Knicks","ppg":28.4},
    {"name":"Jayson Tatum","team":"Celtics","ppg":26.9},
    {"name":"LeBron James","team":"Lakers","ppg":25.1},
    {"name":"Stephen Curry","team":"Warriors","ppg":27.6},
]

@app.route("/")
def home():
    games_html = ""
    for g in DEMO_GAMES:
        games_html += f'''
        <div class="game-card">
            <div class="status">{g["status"]}</div>
            <div class="matchup">
                <span>{g["away"]}</span>
                <span class="score">{g["score"]}</span>
                <span>{g["home"]}</span>
            </div>
        </div>'''
    players_html = ""
    for p in DEMO_PLAYERS:
        players_html += f'''<tr><td>{p["name"]}</td><td>{p["team"]}</td><td>{p["ppg"]}</td></tr>'''
    return f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>ScoutCloud</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:-apple-system,sans-serif;background:#0a0e1a;color:#e2e8f0;min-height:100vh}}
header{{background:#111827;border-bottom:1px solid #1e293b;padding:1rem 2rem;display:flex;justify-content:space-between;align-items:center}}
.logo{{font-size:1.4rem;font-weight:700;color:#f97316}}.logo span{{color:#94a3b8;font-weight:400}}
.badge{{background:#052e16;color:#4ade80;border:1px solid #166534;padding:.3rem .8rem;border-radius:999px;font-size:.75rem;font-weight:600}}
.container{{max-width:960px;margin:0 auto;padding:2rem}}
.section{{margin-bottom:2rem}}
h2{{font-size:.85rem;text-transform:uppercase;letter-spacing:.1em;color:#64748b;margin-bottom:1rem}}
.game-card{{background:#111827;border:1px solid #1e293b;border-radius:12px;padding:1rem 1.5rem;margin-bottom:1rem}}
.status{{font-size:.75rem;color:#f97316;font-weight:700;margin-bottom:.5rem}}
.matchup{{display:flex;justify-content:space-between;align-items:center;font-size:1rem;font-weight:500}}
.score{{font-size:1.4rem;font-weight:700;color:#f1f5f9}}
table{{width:100%;border-collapse:collapse;background:#111827;border-radius:12px;overflow:hidden}}
th{{background:#1e293b;padding:.75rem 1rem;text-align:left;font-size:.75rem;text-transform:uppercase;color:#64748b}}
td{{padding:.75rem 1rem;border-top:1px solid #1e293b;font-size:.9rem}}
footer{{text-align:center;color:#334155;font-size:.75rem;margin-top:3rem;padding-bottom:2rem}}
.instance{{font-family:monospace;color:#f97316}}
</style></head>
<body>
<header><div class="logo">Scout<span>Cloud</span></div><div class="badge">&#9679; System Operational</div></header>
<div class="container">
<div class="section"><h2>Live Games</h2>{games_html}</div>
<div class="section"><h2>Top Players</h2>
<table><tr><th>Player</th><th>Team</th><th>PPG</th></tr>{players_html}</table>
</div>
</div>
<footer>ScoutCloud NBA Intelligence Platform &mdash; Instance: <span class="instance">{HOST}</span></footer>
</body></html>"""

@app.route("/health")
def health():
    import datetime
    try:
        import urllib.request
        instance_id = urllib.request.urlopen(
            "http://169.254.169.254/latest/meta-data/instance-id", timeout=2
        ).read().decode()
    except:
        instance_id = HOST
    with open("/proc/uptime") as f:
        uptime_seconds = int(float(f.read().split()[0]))
    return jsonify(
        status="ok",
        instance_id=instance_id,
        current_time=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        uptime_seconds=uptime_seconds
    )

@app.route("/api/games")
def games():
    return jsonify(games=DEMO_GAMES)

@app.route("/api/players")
def players():
    return jsonify(players=DEMO_PLAYERS)

if __name__ == "__main__":
    app.run()
APPEOF

cat > /etc/systemd/system/scoutcloud.service <<SVCEOF
[Unit]
Description=ScoutCloud Flask app
After=network-online.target
[Service]
Type=simple
WorkingDirectory=/opt/scoutcloud
ExecStart=/usr/local/bin/gunicorn -b 0.0.0.0:8080 -w 2 app:app
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable scoutcloud
systemctl start scoutcloud
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "scoutcloud-web"
      Project = "scoutcloud"
    }
  }
}

data "aws_vpc" "default" { default = true }

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availabilityZone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

resource "aws_security_group" "alb" {
  name        = "scoutcloud-alb-sg"
  description = "ALB ingress - HTTP and HTTPS from internet"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP 8080 for CloudFront"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "web" {
  name               = "scoutcloud-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
  tags               = { Name = "scoutcloud-alb", Project = "scoutcloud" }
}

resource "aws_lb_target_group" "web" {
  name     = "scoutcloud-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    path                = "/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.web.dns_name
}
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = { Name = "scoutcloud-zone", Project = "scoutcloud" }
}

output "nameservers" {
  value       = aws_route53_zone.main.name_servers
  description = "PASTE THESE 4 VALUES INTO CLOUDFLARE"
}

output "domain_name" {
  value = var.domain_name
}
# Route 53 hosted zone for the delegated subdomain
resource "aws_acm_certificate" "alb" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
  tags = { Name = "scoutcloud-cert", Project = "scoutcloud" }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_route53_record" "alb_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "scoutcloud-asg"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  target_group_arns   = [aws_lb_target_group.web.arn]
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "scoutcloud-web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scoutcloud-scale-up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

resource "aws_lb_listener" "cloudfront" {
  load_balancer_arn = aws_lb.web.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
