terraform {
  backend "s3" {
    bucket       = "fintrack-state-722965867897"
    key          = "fintrack/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
