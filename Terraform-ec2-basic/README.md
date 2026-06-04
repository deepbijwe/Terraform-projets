# 🚀 Terraform EC2 Provisioning on AWS

> **Provisioning multiple EC2 instances on AWS using Terraform — with multi-file configuration and the `count` meta-argument.**

![Terraform](https://img.shields.io/badge/Terraform-v1.15.5-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Region](https://img.shields.io/badge/Region-ap--south--1-232F3E?style=for-the-badge&logo=amazonaws&logoColor=white)

---

## 📌 Project Overview

This project demonstrates how to use **Terraform** to provision EC2 instances on AWS from within an EC2 machine itself. The lab covers two approaches:

| Approach | Description |
|---|---|
| **Multi-resource** | Declaring separate `aws_instance` blocks for each EC2 |
| **count meta-argument** | Using `count` + `variable` to dynamically create N instances |

Both approaches use **output blocks** to display instance IDs after provisioning.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   AWS (ap-south-1)                  │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │             Default VPC                      │   │
│  │                                              │   │
│  │  ┌─────────────────┐                         │   │
│  │  │  Terraform Host  │  ← c7i.flex.large      │   │
│  │  │  (i-0fdace...)   │    Ubuntu 26.04        │   │
│  │  │                  │                        │   │
│  │  │  • AWS CLI v2    │                        │   │
│  │  │  • Terraform     │                        │   │
│  │  │    v1.15.5       │                        │   │
│  │  └────────┬─────────┘                        │   │
│  │           │  terraform apply                 │   │
│  │      ┌────┴──────────────────┐               │   │
│  │      │                       │               │   │
│  │  ┌───▼──────────┐  ┌────────▼───────┐        │   │
│  │  │ MyEC2Instance│  │ MyEC2Instance1 │        │   │
│  │  │ t3.micro     │  │ t3.micro       │        │   │
│  │  │ ap-south-1a  │  │ ap-south-1a    │        │   │
│  │  └──────────────┘  └────────────────┘        │   │
│  │                                              │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Tool | Version | Purpose |
|---|---|---|
| Terraform | v1.15.5 | Infrastructure provisioning |
| AWS CLI | v2 | Authentication & API access |
| HashiCorp AWS Provider | v6.47.0 | Terraform ↔ AWS bridge |
| Ubuntu | 26.04 (Resolute) | Host OS on EC2 |
| AMI | ami-07a00cf47dbbc844c | Ubuntu 26.04 base image |

---

## 📁 Project Structure

```
terraform-ec2/
├── ec2.tf          # Provider, resources, outputs, variables
└── README.md       # This file
```

---

## 📋 Prerequisites

Before running this project, ensure you have:

- An AWS account with EC2 permissions
- An EC2 instance (or local machine) to run Terraform from
- AWS IAM credentials (Access Key + Secret Key) with `AmazonEC2FullAccess`
- Internet access from the host machine

---

## ⚙️ Setup & Installation

### Step 1 — Launch a Host EC2 Instance

Launch an EC2 instance (used as the Terraform control machine). In this lab, a `c7i.flex.large` Ubuntu instance was used.

```
Name:          terraform
Instance Type: c7i.flex.large
AMI:           Ubuntu 26.04 LTS (ap-south-1)
```

SSH into the instance:
```bash
ssh -i your-key.pem ubuntu@<PUBLIC_IP>
sudo -i
```

---

### Step 2 — Update System & Install Unzip

```bash
apt update && apt install unzip -y
```

---

### Step 3 — Install AWS CLI v2

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Verify:
```bash
aws --version
```

---

### Step 4 — Configure AWS CLI

```bash
aws configure
```

Provide:
```
AWS Access Key ID:     <your-access-key>
AWS Secret Access Key: <your-secret-key>
Default region name:   ap-south-1
Default output format: json
```

---

### Step 5 — Install Terraform

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Verify:
```bash
terraform --version
# Terraform v1.15.5 on linux_amd64
```

---

## 📄 Terraform Configuration

### Approach 1 — Explicit Multi-Resource

Two separate `aws_instance` resource blocks, each with a unique logical name and tag.

```hcl
provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "my-ec2-instance" {
  ami           = "ami-07a00cf47dbbc844c"
  instance_type = "t3.micro"
  tags = {
    Name = "MyEC2Instance"
  }
}

resource "aws_instance" "my-ec2-instance1" {
  ami           = "ami-07a00cf47dbbc844c"
  instance_type = "t3.micro"
  tags = {
    Name = "MyEC2Instance1"
  }
}

output "instance_id" {
  value = aws_instance.my-ec2-instance.id
}

output "instance_id1" {
  value = aws_instance.my-ec2-instance1.id
}
```

---

### Approach 2 — Dynamic Provisioning with `count`

Uses a `variable` for instance count and `count.index` for unique naming. Cleaner and scalable.

```hcl
provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "my-ec2-instance" {
  ami           = "ami-07a00cf47dbbc844c"
  count         = var.instance_count
  instance_type = "t3.micro"
  tags = {
    Name = "MyEC2Instance-${count.index + 1}"
  }
}

output "instance_ids" {
  value = aws_instance.my-ec2-instance[*].id
}

variable "instance_count" {
  default = 2
}
```

---

## 🚀 Terraform Commands

### Initialize (download provider plugins)
```bash
terraform init
```

Expected output:
```
- Installing hashicorp/aws v6.47.0...
- Installed hashicorp/aws v6.47.0 (signed by HashiCorp)
Terraform has been successfully initialized!
```

### Preview changes
```bash
terraform plan
```

Shows a dry-run: what will be **created**, **modified**, or **destroyed** — before touching real infrastructure.

### Apply (provision resources)
```bash
terraform apply --auto-approve
```

Expected output:
```
aws_instance.my-ec2-instance:  Creation complete after 12s [id=i-052ad038dd0c12d74]
aws_instance.my-ec2-instance1: Creation complete after 12s [id=i-0391b1a98652a95ed]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:
instance_id  = "i-052ad038dd0c12d74"
instance_id1 = "i-0391b1a98652a95ed"
```

### Destroy (clean up resources)
```bash
terraform destroy --auto-approve
```

Terminates all resources tracked in the Terraform state file.

---

## 📸 Project Screenshots

| Step | Screenshot |
|---|---|
| Host EC2 (terraform) running | EC2 instance details — c7i.flex.large |
| AWS CLI installation | curl + unzip + install |
| Terraform installed | `terraform --version` → v1.15.5 |
| ec2.tf configuration | Viewed in vim on the server |
| `terraform init` | Provider hashicorp/aws v6.47.0 installed |
| `terraform plan` | 2 resources to add |
| `terraform apply` | Both instances created in ~12s |
| AWS Console | MyEC2Instance & MyEC2Instance1 running |
| `terraform destroy` | Both instances shutting down |

---

## 💡 Key Concepts Learned

| Concept | What It Does |
|---|---|
| `provider` block | Tells Terraform which cloud and region to use |
| `resource` block | Declares infrastructure to be created |
| `output` block | Prints values (like instance IDs) after apply |
| `variable` block | Makes configs reusable and dynamic |
| `count` meta-argument | Creates multiple copies of a resource |
| `count.index` | Zero-based index for naming/differentiating instances |
| `terraform init` | Downloads provider plugins |
| `terraform plan` | Dry-run — shows what will change |
| `terraform apply` | Provisions the actual infrastructure |
| `terraform destroy` | Tears down all managed resources |
| `.terraform.lock.hcl` | Locks provider versions for reproducibility |

---

## ⚠️ Important Notes

- The AMI `ami-07a00cf47dbbc844c` is **Ubuntu 26.04** and is **region-specific** (ap-south-1). Use the correct AMI ID for your region.
- Always run `terraform destroy` after the lab to **avoid unexpected AWS charges**.
- Never hardcode AWS credentials in `.tf` files. Use `aws configure` or IAM roles instead.
- The `--auto-approve` flag skips the interactive confirmation prompt — use carefully in production.

---

## 🔗 Connect

**GitHub:** [@deepbijwe](https://github.com/deepbijwe)  
**AWS Projects:** [deepbijwe/AWS-projects](https://github.com/deepbijwe/AWS-projects)

---

*Built with 💙 as part of a hands-on DevOps learning journey.*