variable "project" {
  description = "Project name prefix."
  type        = string
  default     = "atf"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "region" {
  description = "Primary AWS region (EC2 + S3)."
  type        = string
  default     = "eu-west-2"
}

variable "frontend_bucket_name" {
  description = "Globally unique S3 bucket name for the frontend."
  type        = string
}

variable "enable_model_bucket" {
  description = "Create a model S3 bucket; the backend auto-pulls the model from it on boot."
  type        = bool
  default     = true
}

variable "model_bucket_name" {
  description = "Globally unique S3 bucket name for the trained model. Required when enable_model_bucket is true."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for the EC2 key pair. Empty = no key pair (use SSM)."
  type        = string
  default     = ""
}

variable "ssh_ingress_cidrs" {
  description = "CIDRs allowed SSH access (e.g. [\"203.0.113.4/32\"])."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "Backend EC2 instance type."
  type        = string
  default     = "m7i-flex.large"
}

variable "enable_waf" {
  description = "Create and attach the WAF Web ACL."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------ CI/CD: GitHub OIDC
variable "create_github_oidc_role" {
  description = "Create the GitHub Actions OIDC role (preferred over static keys)."
  type        = bool
  default     = true
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN, used when create_github_oidc_provider is false."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Repo allowed to assume the role, \"owner/repo\" (e.g. MartinSG98/ai_text_flagger_ui)."
  type        = string
  default     = ""
}

variable "github_oidc_subjects" {
  description = "Explicit OIDC subject patterns. Overrides the default (main branch of github_repository)."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------ CI/CD: legacy user
variable "create_cicd_user" {
  description = "Create a legacy static-key IAM user (off by default; prefer OIDC)."
  type        = bool
  default     = false
}
