terraform {
  backend "s3" {
    bucket       = "jadelzein-eks-platform-tfstate-45033523"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
