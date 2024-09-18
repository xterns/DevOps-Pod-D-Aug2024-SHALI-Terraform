output "instance_id" {
  description = "ID of the EC2 instance"
  value       = var.use_asg ? null : aws_instance.pkrtf[0].id
}

output "asg_id" {
  description = "ID of the Auto Scaling Group"
  value       = var.use_asg ? aws_autoscaling_group.asg[0].id : null
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = var.use_asg ? aws_autoscaling_group.asg[0].name : null
}
