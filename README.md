# tf-stack-ai_text_flagger

Terraform stack that deploys AI Text Flagger, a fine-tuned BERT classifier that tells human-written text from AI-generated text, to AWS. This is the configuration you apply. It sets up the two AWS providers and calls the module at a pinned tag, and the module builds the S3 bucket for the frontend, the S3 bucket for the model, the EC2 instance that runs the API, CloudFront with a WAF web ACL in front of them, and the IAM for the instance and for GitHub Actions deploys.

The module lives in [tf-module-ai_text_flagger](https://github.com/MartinSG98/tf-module-ai_text_flagger), and its README lists every resource, behavior and WAF rule. The application lives in [ai_text_flagger](https://github.com/MartinSG98/ai_text_flagger) (the model and the API) and [ai_text_flagger_ui](https://github.com/MartinSG98/ai_text_flagger_ui) (the frontend).

```
User → CloudFront (HTTPS, WAF) ─┬─ default (*) → S3 frontend bucket (private, via OAC)
                                ├─ /predict*   → EC2 backend, FastAPI on :8000 (HTTP)
                                └─ /health     → EC2 backend, FastAPI on :8000 (HTTP)

EC2 instance role   → S3 model bucket (read, on first boot)
GitHub Actions OIDC → deploy role → S3 frontend sync + CloudFront invalidation
```

## What it creates

| Piece | What it is | Set by |
|---|---|---|
| Frontend bucket | Private, versioned and encrypted, readable only by the distribution through Origin Access Control | `frontend_bucket_name` |
| Model bucket | Private, versioned and encrypted. The instance pulls the model from it on first boot | `model_bucket_name`, off with `enable_model_bucket = false` |
| Backend instance | Ubuntu 24.04 with a 20 GB gp3 volume and an Elastic IP, running the API as the systemd service `atf` on port 8000 | `instance_type`, `ssh_public_key`, `ssh_ingress_cidrs` |
| Instance role | Session Manager access and read access to the model bucket | always created |
| CloudFront distribution | S3 for everything by default, the instance for `/predict*` and `/health`, and a function that sends extension-less paths to `/index.html` | always created |
| WAF web ACL | In us-east-1: the AWS Common Rule Set with four body rules set to Count, Known Bad Inputs, and a rate limit of 2,000 requests per IP in five minutes | off with `enable_waf = false` |
| GitHub deploy role | Assumed through OIDC by the main branch of `github_repository`, allowed to sync the frontend bucket and invalidate the distribution | `github_repository`, off with `create_github_oidc_role = false` |
| Legacy deploy user | IAM user with the same permissions and a static access key | off unless `create_cicd_user = true` |

Settings this stack does not pass, such as the API port, the volume size, the Elastic IP, the price class and the WAF rate limit, keep the module's defaults. Add them to `main.tf` to change them.

## Providers

`versions.tf` requires Terraform 1.5.0 or newer and the `hashicorp/aws` provider 5.40.0 or newer. `providers.tf` configures the default `aws` provider in `var.region` and an `aws.us_east_1` alias in us-east-1, because a CLOUDFRONT-scope web ACL (and any ACM certificate for a custom domain) has to live there. Both add the default tags `Project` and `ManagedBy`, and both are passed to the module.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan
terraform apply
```

`terraform.tfvars` is git-ignored. The example sets the two bucket names, the project, environment, region and instance type, turns WAF on and names the UI repo for the deploy role, with the SSH and OIDC options commented out. Both bucket names have to be globally unique, so pick your own.

The first apply runs with your own AWS credentials, which need the rights to create all of the above. The OIDC role is only for the UI's deploy workflow, not for running Terraform.

`main.tf` pins the module at `v1.1.0`:

```hcl
source = "git::https://github.com/MartinSG98/tf-module-ai_text_flagger.git?ref=v1.1.0"
```

For local work on both repos side by side, switch it to `source = "../module"` for a while. To move to a newer module version, bump `?ref=`, then:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## Inputs

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `project` | string | `"atf"` | First part of resource names and the `Project` tag |
| `environment` | string | `"prod"` | Second part of resource names |
| `region` | string | `"eu-west-2"` | Region of the default provider, so of the instance and both buckets |
| `frontend_bucket_name` | string | required | Globally unique name of the frontend bucket |
| `enable_model_bucket` | bool | `true` | Create the model bucket and have the instance pull the model from it on boot |
| `model_bucket_name` | string | `""` | Globally unique name of the model bucket. Required when `enable_model_bucket` is true |
| `ssh_public_key` | string | `""` | Public key for an EC2 key pair. Empty creates no key pair, and Session Manager is the way in |
| `ssh_ingress_cidrs` | list(string) | `[]` | CIDR blocks allowed on port 22, such as your own IP as a `/32`. Empty opens no SSH |
| `instance_type` | string | `"m7i-flex.large"` | Backend instance type |
| `enable_waf` | bool | `true` | Create the web ACL and attach it to the distribution |
| `create_github_oidc_role` | bool | `true` | Create the role GitHub Actions assumes through OIDC |
| `create_github_oidc_provider` | bool | `true` | Create the GitHub OIDC provider. Set false and pass `github_oidc_provider_arn` if the account already has one |
| `github_oidc_provider_arn` | string | `""` | ARN of the existing provider, used when `create_github_oidc_provider` is false |
| `github_repository` | string | `""` | `owner/repo` allowed to assume the role, here `MartinSG98/ai_text_flagger_ui` |
| `github_oidc_subjects` | list(string) | `[]` | Subject patterns that replace the default (the main branch of `github_repository`), for example to allow a GitHub environment |
| `create_cicd_user` | bool | `false` | Create the legacy IAM user with a static access key |

## Outputs

| Output | What it is |
|---|---|
| `app_url` | `https://` plus the CloudFront domain, the public URL of the app |
| `cloudfront_distribution_id` | ID of the distribution, for the UI workflow's `CLOUDFRONT_DISTRIBUTION_ID` |
| `cloudfront_domain_name` | The distribution's `*.cloudfront.net` domain |
| `frontend_bucket` | Name of the frontend bucket, for the UI workflow's `AWS_S3_BUCKET` |
| `model_bucket` | Name of the model bucket, where the trained model goes |
| `backend_public_ip` | Public address of the instance |
| `backend_instance_id` | ID of the instance, for Session Manager |
| `github_actions_role_arn` | ARN of the deploy role, for `role-to-assume` in the workflow |
| `github_oidc_provider_arn` | ARN of the OIDC provider the role trusts |
| `cicd_access_key_id` | Access key ID of the legacy user, null unless it is enabled |
| `cicd_secret_access_key` | Its secret key, marked sensitive. Read it with `terraform output -raw cicd_secret_access_key` |

## Deployment notes

After the first apply, three things are left to do by hand.

1. **Upload the model.** It is about 1.3 GB and not in git. Read the bucket name here, then sync from the backend repo:

   ```bash
   terraform output -raw model_bucket                                # in this repo
   aws s3 sync output/model/final/ "s3://<model-bucket>/model/final/"   # in the backend repo
   ```

   The instance pulls the model on its first boot only. If it booted before the upload, run the same sync on the instance through Session Manager, or replace the instance.
2. **Set the API key.** User data does not write it. Open a shell on the instance with Session Manager (the AWS CLI needs the Session Manager plugin for this), write the key and restart the service:

   ```bash
   aws ssm start-session --target "$(terraform output -raw backend_instance_id)"
   # then, on the instance
   echo "API_KEY=<your-key>" | sudo -u ubuntu tee /home/ubuntu/ai_text_flagger/.env
   sudo systemctl restart atf
   ```

   Until then the predict routes answer 500. The file lives on the instance's root volume, so it has to be written again whenever the instance is replaced, which happens on any change to its user data.
3. **Deploy the UI.** The frontend bucket starts empty. Push to main in the UI repo to run its workflow, or build and sync it once by hand. Then check the whole path through CloudFront:

   ```bash
   curl "$(terraform output -raw app_url)/health"
   ```

The UI repo's workflow still signs in with a static access key from the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets. One way to feed it is `create_cicd_user = true` and the two `cicd_` outputs. The other is the OIDC role, which needs no stored keys. Store the role ARN as a repository variable and switch the workflow to this:

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
          node-version: "22"
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

| GitHub setting | Comes from |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` (variable) | `github_actions_role_arn` |
| `AWS_S3_BUCKET` (variable) | `frontend_bucket` |
| `CLOUDFRONT_DISTRIBUTION_ID` (variable) | `cloudfront_distribution_id` |
| `VITE_API_URL` (secret) | `app_url` |
| `VITE_API_KEY` (secret) | The backend's API key, which this stack does not manage |

The role only trusts pushes to main of `github_repository` unless `github_oidc_subjects` says otherwise.

State is local by default. `versions.tf` has a commented-out S3 backend with native locking (`use_lockfile`, which needs Terraform 1.10 or newer). Create the state bucket separately, fill in its name and uncomment the block to share state. Keep the state private either way, because the legacy user's secret key ends up in it when that user is on.

Neither bucket sets `force_destroy`, and both are versioned, so empty them (every version) before `terraform destroy`.

The hosted demo is switched off for billing reasons.
