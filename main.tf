# Deployment stack for AI Text Flagger.
#
# The module lives in its OWN repo and is consumed from a PINNED version (git
# tag), so deployments are reproducible and upgrades are explicit. Tag the
# module repo (`git tag v1.0.0 && git push --tags`) and bump ?ref= to roll
# forward.
#
# TODO: replace the URL below with your actual module repo.
# For local development with both folders side by side, temporarily switch to:
#   source = "../module"

module "ai_text_flagger" {
  source = "git::https://github.com/MartinSG98/tf-module-ai_text_flagger.git?ref=v1.0.0"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = var.project
  environment = var.environment
  region      = var.region

  frontend_bucket_name = var.frontend_bucket_name

  instance_type     = var.instance_type
  ssh_public_key    = var.ssh_public_key
  ssh_ingress_cidrs = var.ssh_ingress_cidrs

  enable_waf = var.enable_waf

  # CI/CD: GitHub Actions OIDC role (no static keys).
  create_github_oidc_role     = var.create_github_oidc_role
  create_github_oidc_provider = var.create_github_oidc_provider
  github_oidc_provider_arn    = var.github_oidc_provider_arn
  github_repository           = var.github_repository
  github_oidc_subjects        = var.github_oidc_subjects

  # Legacy static-key user (off by default).
  create_cicd_user = var.create_cicd_user
}
