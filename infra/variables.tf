variable "github_username" {
  description = "Your GitHub username — used to clone your ScoutCloud repo"
  type        = string
}
variable "domain_name" {
  description = "Your registered domain (e.g. scoutcloud.dev)"
  type        = string
}

variable "ec2_public_key" {
  description = "Public key for EC2 key pair"
  default     = ""
}
