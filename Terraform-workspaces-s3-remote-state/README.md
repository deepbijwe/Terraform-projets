# Terraform Workspaces + S3 Remote State Backend

> Multi-environment EC2 provisioning using Terraform Workspaces with S3 as a remote state backend and native state locking — no DynamoDB required.

---

## Project Overview

This project demonstrates how to manage **multiple environment-specific Terraform states** using Terraform Workspaces, and how to migrate from local state storage to a **remote S3 backend** with built-in state locking.

Deployed on an AWS EC2 instance (Ubuntu 26.04 LTS) in the `ap-south-1` (Mumbai) region.

---

## Architecture

```
EC2 Instance (ip-172-31-12-37)
│
├── Terraform CLI v1.15.5
│   └── AWS Provider v6.49.0
│
├── Workspaces
│   ├── default
│   ├── deep-test
│   ├── env
│   └── prod
│
└── ec2.tf (S3 backend config)
        │
        │  terraform init -migrate-state
        ▼
S3 Bucket: deep-terraform-state (ap-south-1)
│   Versioning: Enabled
│   Encryption: Enabled
│   Locking: use_lockfile = true (S3 native)
│
└── env:/
    ├── default/workspaces/terraform.tfstate
    ├── deep-test/workspaces/terraform.tfstate
    ├── env/workspaces/terraform.tfstate
    └── prod/workspaces/terraform.tfstate
```

---

## Tech Stack

| Tool | Version | Purpose |
|---|---|---|
| Terraform | v1.15.5 | Infrastructure as Code |
| AWS Provider | v6.49.0 | AWS resource management |
| AWS CLI | v2 | Bucket and table creation |
| EC2 (Ubuntu 26.04 LTS) | t3.small | Terraform execution host |
| S3 | — | Remote state backend |

---

## Prerequisites

- AWS account with an EC2 instance (Ubuntu) in `ap-south-1`
- IAM role/user with S3, EC2, and DynamoDB permissions
- AWS CLI v2 installed and configured (`aws configure`)
- Terraform installed via snap

---

## Step-by-Step Setup

### Step 1 — Install AWS CLI on EC2

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### Step 2 — Configure AWS credentials

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (ap-south-1), Output (json)
```

### Step 3 — Install Terraform via snap

```bash
sudo snap install terraform --classic
terraform --version
```

### Step 4 — Create Terraform Workspaces

```bash
# Create and switch to each environment workspace
terraform workspace new deep-test
terraform workspace new env
terraform workspace new prod

# List all workspaces
terraform workspace list

# Switch between workspaces
terraform workspace select deep-test
```

> Each workspace maintains its own isolated state file. This allows the same `.tf` configuration to deploy separate infrastructure per environment.

### Step 5 — Write the EC2 configuration

```bash
vim ec2.tf
```

```hcl
terraform {
  backend "s3" {
    bucket       = "deep-terraform-state"
    key          = "workspaces/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "my-ec2-instance" {
  ami           = "ami-0f58b397bc5c1f2e8"   # Ubuntu 22.04 ap-south-1
  instance_type = "t3.micro"

  tags = {
    Name = "MyEC2Ins-${terraform.workspace}"
  }
}

output "instance_id" {
  value = aws_instance.my-ec2-instance.id
}
```

### Step 6 — Create the S3 Bucket for Remote State

```bash
# Create bucket in correct region
aws s3api create-bucket \
  --bucket deep-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable versioning (allows state history and rollback)
aws s3api put-bucket-versioning \
  --bucket deep-terraform-state \
  --region ap-south-1 \
  --versioning-configuration Status=Enabled
```

### Step 7 — Initialize and Migrate State to S3

```bash
terraform init -migrate-state
```

When prompted:
```
Do you want to migrate all workspaces to "s3"? yes
```

Terraform will copy all local workspace state files to S3 automatically.

### Step 8 — Verify Migration

```bash
# Confirm state is readable from S3
terraform state list

# Check S3 directly
aws s3 ls s3://deep-terraform-state --recursive --region ap-south-1
```

Expected output:
```
env:/deep-test/workspaces/terraform.tfstate
env:/env/workspaces/terraform.tfstate
env:/prod/workspaces/terraform.tfstate
```

### Step 9 — Deploy EC2 per Workspace

```bash
# Switch to a workspace and apply
terraform workspace select deep-test
terraform apply

terraform workspace select env
terraform apply

terraform workspace select prod
terraform apply
```

Each workspace creates an EC2 instance tagged with its environment name.

---

## State Locking Explained

With **AWS Provider v6+**, state locking works natively via S3 — no DynamoDB table needed.

When `terraform apply` runs, Terraform creates a `.tflock` file in S3:

```
env:/deep-test/workspaces/terraform.tfstate.tflock
```

This lock prevents concurrent applies from corrupting state. The lock is automatically released when the operation completes.

| Locking Method | AWS Provider | Extra Resource |
|---|---|---|
| `dynamodb_table` (deprecated) | v5 and below | DynamoDB table required |
| `use_lockfile = true` (current) | v6+ | None — S3 native |

---

## Errors Encountered and Fixed

### Error 1 — Typo in Terraform command

**Symptom:**
```
Command 'terrafrom' not found
```

**Cause:** Typo — `terrafrom` instead of `terraform`

**Fix:** Correct the command spelling.

---

### Error 2 — Wrong Terraform workspace subcommand

**Symptom:**
```
Terraform has no command named "create"
```

**Cause:** Used `terraform create workspace dev` instead of the correct subcommand.

**Fix:**
```bash
terraform workspace new dev
```

---

### Error 3 — Reference to undeclared resource (typo in `.tf` file)

**Symptom:**
```
Error: Reference to undeclared resource
on ec2.tf line 25, in output "instance_id":
  value = aws_instacne.my-ec2-instance.id
A managed resource "aws_instacne" "my-ec2-instance" has not been declared
```

**Cause:** Typo in the output block — `aws_instacne` instead of `aws_instance`

**Fix:** Corrected the resource type spelling in `ec2.tf`, then re-ran `terraform apply`.

---

### Error 4 — S3 bucket in wrong region (301 Redirect)

**Symptom:**
```
Error: Unable to list objects in S3 bucket "deep-terraform-state" with prefix "env:/"
StatusCode: 301 — requested bucket from "ap-south-1", actual location "us-east-1"
```

**Cause:** S3 bucket was accidentally created in `us-east-1` (default region) but the backend config specified `ap-south-1`.

**Fix:**
```bash
# Delete the wrong bucket
aws s3 rb s3://deep-terraform-state --force --region us-east-1

# Recreate in correct region
aws s3api create-bucket \
  --bucket deep-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

---

### Error 5 — Deprecated `dynamodb_table` parameter warning

**Symptom:**
```
Warning: Deprecated Parameter
  dynamodb_table = "terraform-state-lock"
  Use parameter "use_lockfile" instead.
```

**Cause:** AWS Provider v6 replaced DynamoDB-based locking with native S3 file locking.

**Fix:** Updated backend config:
```hcl
# Before (deprecated)
dynamodb_table = "terraform-state-lock"

# After (current)
use_lockfile = true
```

---

### Error 6 — `prod` workspace missing after migration

**Symptom:**
```
Workspace "prod" doesn't exist.
```

**Cause:** The `prod` workspace was created but never had `terraform apply` run on it, so its local state file was empty. Terraform only migrates workspaces that have actual state.

**Fix:**
```bash
terraform workspace new prod
```

Since `prod` had no infrastructure, recreating it as a fresh workspace is correct — no state was lost.

---

## Key Learnings

- **Workspaces isolate state, not configuration.** The same `.tf` files are reused across all workspaces — only the state file changes. Use `terraform.workspace` in resource tags to distinguish environments.

- **S3 bucket region must match the backend config region.** Creating a bucket without `--create-bucket-configuration LocationConstraint=<region>` defaults to `us-east-1`, causing a 301 redirect error.

- **AWS Provider v6 eliminates the need for DynamoDB.** `use_lockfile = true` stores the lock directly in S3. This simplifies the backend setup significantly.

- **Empty workspaces are not migrated.** A workspace must have at least one `terraform apply` run before its state file is created. Only state-bearing workspaces are migrated by `terraform init -migrate-state`.

- **Always check your region.** The most common source of errors in this project was region mismatch — between the bucket, the EC2 instance, and the backend config.

---

## Final Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket       = "deep-terraform-state"
    key          = "workspaces/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

---

## Cleanup

```bash
# Destroy infrastructure in each workspace before deleting
terraform workspace select deep-test && terraform destroy
terraform workspace select env       && terraform destroy
terraform workspace select prod      && terraform destroy
terraform workspace select default   && terraform destroy

# Delete S3 bucket (empty it first)
aws s3 rm s3://deep-terraform-state --recursive --region ap-south-1
aws s3api delete-bucket --bucket deep-terraform-state --region ap-south-1
```

---

## Author

**Deep Bijwe**  
Cloud DevOps Enginner
AWS Certified Cloud Practitioner (CLF-C02)  
[LinkedIn](https://linkedin.com/in/deep-bijwe) · [GitHub](https://github.com/deepbijwe/AWS-projects)