# ai_text_flagger_tf_stack

Deployment **stack** for AI Text Flagger. This is the configuration you actually
`apply`. It consumes the reusable module from a pinned version (separate repo):

```
User → CloudFront (HTTPS + WAF) ─┬─ default (*)  → S3 (React frontend, private via OAC)
                                 ├─ /predict*     → EC2 (FastAPI backend, :8000)
                                 └─ /health       → EC2 (FastAPI backend, :8000)
```

The module lives in its own repo (`tf-module-ai_text_flagger`) and is referenced
in `main.tf`:

```hcl
source = "git::https://github.com/MartinSG98/tf-module-ai_text_flagger.git?ref=v1.0.0"
```

> Update that URL to your module repo. For local development with both folders
> checked out side by side, temporarily switch to `source = "../module"`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan
terraform apply
```

Requires Terraform >= 1.5 and AWS credentials with permission to create the
resources. The first apply uses your own admin credentials; the OIDC role created
here is only for the CI/CD deploy workflow, not for running Terraform.

### Key inputs (`terraform.tfvars`)

| Variable                | Notes |
|-------------------------|-------|
| `frontend_bucket_name`  | Globally unique S3 name (README used `atf-frontend-ew2`). |
| `model_bucket_name`     | Globally unique S3 name for the model (backend pulls it on boot). |
| `enable_model_bucket`   | Create the model bucket + auto-pull (default `true`). |
| `region`                | Primary region, default `eu-west-2`. |
| `instance_type`         | Backend EC2 size, default `m7i-flex.large`. |
| `ssh_public_key`        | Optional — creates an EC2 key pair. Empty = SSM-only access. |
| `ssh_ingress_cidrs`     | Lock SSH to your IP, e.g. `["203.0.113.4/32"]`. |
| `enable_waf`            | Create + attach the WAF Web ACL (default `true`). |
| `github_repository`     | `owner/repo` allowed to assume the OIDC role (the frontend repo). |
| `create_github_oidc_provider` | `false` + pass `github_oidc_provider_arn` if the account already has one. |
| `create_cicd_user`      | Legacy static-key user (default `false`; prefer OIDC). |

## Upgrading the module

```bash
# bump ?ref=v1.0.0 -> ?ref=v1.1.0 in main.tf, then:
terraform init -upgrade
terraform plan
terraform apply
```

## CI/CD with GitHub OIDC (no static keys)

The stack creates an IAM **role** assumed by GitHub Actions via OIDC, scoped to
`github_repository` (main branch by default). After apply:

```bash
terraform output -raw github_actions_role_arn
```

Set it as the `AWS_DEPLOY_ROLE_ARN` repo variable, then use this workflow in the
**frontend** repo (`.github/workflows/deploy.yml`) — no AWS keys required:

```yaml
name: Deploy to S3

on:
  push:
    branches: [main]

permissions:
  id-token: write      # required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm ci
      - name: Create .env.production
        run: |
          echo "VITE_API_URL=${{ secrets.VITE_API_URL }}" >> .env.production
          echo "VITE_API_KEY=${{ secrets.VITE_API_KEY }}" >> .env.production
      - run: npm run build
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: eu-west-2
      - name: Sync to S3
        run: aws s3 sync dist/ "s3://${{ vars.AWS_S3_BUCKET }}" --delete
      - name: Invalidate CloudFront
        run: aws cloudfront create-invalidation --distribution-id "${{ vars.CLOUDFRONT_DISTRIBUTION_ID }}" --paths '/*'
```

| GitHub variable               | Terraform output |
|-------------------------------|------------------|
| `AWS_DEPLOY_ROLE_ARN`         | `github_actions_role_arn` |
| `AWS_S3_BUCKET`               | `frontend_bucket` |
| `CLOUDFRONT_DISTRIBUTION_ID`  | `cloudfront_distribution_id` |
| `VITE_API_URL`                | `app_url` |
| `VITE_API_KEY` (secret)       | your backend API key — not managed here |

## After `apply`

### 1. Upload the trained model (once)

The model is too large for git. With `enable_model_bucket = true`, upload it to
the model bucket; the backend syncs it from there on boot:

```bash
aws s3 sync output/model/final/ "s3://$(terraform output -raw model_bucket)/model/final/"
```

A fresh/replaced instance auto-pulls it via its IAM role — no scp needed. If you
upload after the instance is already running, restart the service to pick it up
(e.g. via SSM Session Manager): `sudo systemctl restart atf`.

Also create `/home/ubuntu/ai_text_flagger/.env` with `API_KEY=...` (read by the
systemd unit via `EnvironmentFile`).

### 2. Deploy the frontend

The bucket starts empty — push to `main` to run the workflow above, or sync once:

```bash
aws s3 sync dist/ "s3://$(terraform output -raw frontend_bucket)" --delete
```

## State

Local by default. Uncomment the S3 backend in `versions.tf` for shared/remote
state, and keep state private (the legacy user's secret key, if enabled, is
stored there).
