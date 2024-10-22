resource "aws_security_group" "ec2_security_group" {
  name        = "Podsg2"
  description = "allow access on ports 80, 22, and 443"

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

module "network" {
  source             = "./modules/network"
  instance_count     = var.instance_count
  instance_type      = var.instance_type
  key_name           = var.key_name
  security_group_ids = [module.security.security_ext]
  name_prefix        = var.name_prefix
  environment        = var.environment
  tags               = var.tags
}
