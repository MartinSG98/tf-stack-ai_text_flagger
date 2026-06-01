terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }

  # ---- Remote state (recommended). Uncomment and configure for shared state.
  # ---- Create the bucket out-of-band first. use_lockfile requires TF >= 1.10.
  # backend "s3" {
  #   bucket       = "atf-tfstate-ew2"
  #   key          = "ai-text-flagger/prod/terraform.tfstate"
  #   region       = "eu-west-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
