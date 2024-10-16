variable "aws_region" {
  description = "The AWS region to create things in."
  type        = string
  default     = "us-east-1"
}
variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance or ASG"
  type        = string
  default     = "ami-0e86e20dae9224db8"
}
variable "instance_type" {
  description = "The instance type to use for the EC2 instance or ASG"
  type        = string
  default     = "t2.micro"
}
variable "key_name" {
  description = "The key pair name to use for the EC2 instance or ASG"
  type        = string
  default     = "pkr-key"
}
variable "use_asg" {
  description = "Whether to use an Autoscaling Group (true) or standalone EC2 instance (false)"
  type        = bool
  default     = false
}
variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}
variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}
variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 1
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "name_prefix" {
  description = "Prefix for the instance name tag"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., sandbox, staging, production)"
  type        = string
}

variable "tags" {
  description = "Additional tags for the instance"
  type        = map(string)
  default     = {}
}
