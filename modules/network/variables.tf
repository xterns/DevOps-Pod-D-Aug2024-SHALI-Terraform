# modules/ec2/variables.tf

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "name_prefix" {
  description = "Prefix for the instance name tag"
  type        = string
}

variable "environment" {
  description = "Environment (sandbox, staging, production)"
  type        = string
}

variable "tags" {
  description = "Additional tags for the instance"
  type        = map(string)
  default     = {}
}