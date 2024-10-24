terraform {
  backend "s3" {
    bucket = "xternal-terraform-bucket"
    key    = "tfstate-bucket"
    region = "us-east-1
    dynamodb_table = "terraform-db-lock-table"
    encrypt        = true
  }
}
