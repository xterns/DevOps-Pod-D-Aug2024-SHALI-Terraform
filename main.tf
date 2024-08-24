terraform {
  backend "s3" {
    bucket = "devops-pod-d-for-terraform"
    key    = "xtern/DevOps-Pod-D-Aug2024-SHALI-Terraform/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
