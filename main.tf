# main Terraform configuration file

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "example" {
  bucket = "example-bucket-${random_pet.name.id}"
}


