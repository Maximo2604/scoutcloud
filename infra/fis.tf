# FIS requires paid subscription - architecture documented in runbook

# resource "aws_iam_role" "fis" {
#   name = "scoutcloud-fis-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{ Effect = "Allow", Principal = { Service = "fis.amazonaws.com" }, Action = "sts:AssumeRole" }]
#   })
# }

# resource "aws_iam_role_policy" "fis" {
#   name = "fis-policy"
#   role = aws_iam_role.fis.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = ["ec2:TerminateInstances", "ec2:DescribeInstances", "autoscaling:DescribeAutoScalingGroups"]
#       Resource = "*"
#     }]
#   })
# }

# resource "aws_fis_experiment_template" "terminate_instance" {
#   description = "Terminate one ASG instance - verify ASG replaces it"
#   role_arn    = aws_iam_role.fis.arn

#   action {
#     name      = "terminate-instance"
#     action_id = "aws:ec2:terminate-instances"
#     target {
#       key   = "Instances"
#       value = "one-instance"
#     }
#   }

#   target {
#     name           = "one-instance"
#     resource_type  = "aws:ec2:instance"
#     selection_mode = "COUNT(1)"
#     resource_tag {
#       key   = "aws:autoscaling:groupName"
#       value = "scoutcloud-asg"
#     }
#   }

#   stop_condition {
#     source = "none"
#   }

#   tags = local.common_tags
# }

# output "fis_template_id" { value = aws_fis_experiment_template.terminate_instance.id }
