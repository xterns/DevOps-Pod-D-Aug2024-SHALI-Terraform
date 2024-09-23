resource "aws_security_group" "ec2_security_group" {
  name        = "Podsg"
  description = "allow access on ports 80 and 22 and 443"

  ingress {
    description      = "ssh access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Pod-D"
  }
}

resource "aws_instance" "Podtf" {
  count                  = var.use_asg ? 0 : 1
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  tags = {
    Name = "Pod-D-EC2"
  }
}

resource "aws_launch_template" "asg_launch_template" {
  count         = var.use_asg ? 1 : 0
  name_prefix   = "asg-launch-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Pod-D-ASG-Instance"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  count               = var.use_asg ? 1 : 0
  name                = "Pod-D-ASG"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.asg_launch_template[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "Pod-D-ASG-Instance"
    propagate_at_launch = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
