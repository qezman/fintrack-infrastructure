terraform {
  # backend "s3" {
  #   bucket       = "fintrack-state-722965867897"
  #   key          = "fintrack/dev/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }

  backend "s3" {
    bucket       = "tf-reviewer-state-722965867897" # shared state bucket from bootstrap
    key          = "fintrack/dev/terraform.tfstate" # separate path, so it never touches bootstrap's state
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # drop any old dynamodb_table line
  }
}
