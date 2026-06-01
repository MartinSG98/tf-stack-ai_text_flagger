output "app_url" {
  description = "Public HTTPS URL of the application."
  value       = module.ai_text_flagger.app_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (CI: CLOUDFRONT_DISTRIBUTION_ID)."
  value       = module.ai_text_flagger.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name."
  value       = module.ai_text_flagger.cloudfront_domain_name
}

output "frontend_bucket" {
  description = "Frontend S3 bucket name (CI: AWS_S3_BUCKET)."
  value       = module.ai_text_flagger.frontend_bucket
}

output "backend_public_ip" {
  description = "Public IP of the backend EC2 instance."
  value       = module.ai_text_flagger.backend_public_ip
}

output "backend_instance_id" {
  description = "Backend EC2 instance ID."
  value       = module.ai_text_flagger.backend_instance_id
}

# ---- CI/CD: GitHub Actions OIDC ----
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC (workflow: role-to-assume)."
  value       = module.ai_text_flagger.github_actions_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN."
  value       = module.ai_text_flagger.github_oidc_provider_arn
}

# ---- CI/CD: legacy access-key user (only when create_cicd_user = true) ----
output "cicd_access_key_id" {
  description = "Access key ID for the legacy CI/CD user (CI: AWS_ACCESS_KEY_ID)."
  value       = module.ai_text_flagger.cicd_access_key_id
}

output "cicd_secret_access_key" {
  description = "Secret key for the legacy CI/CD user. View: terraform output -raw cicd_secret_access_key"
  value       = module.ai_text_flagger.cicd_secret_access_key
  sensitive   = true
}
