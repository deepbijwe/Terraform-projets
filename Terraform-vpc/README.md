# 🏗️ AWS VPC Infrastructure with Terraform

> Provision a production-style, two-tier AWS VPC from scratch using Terraform — including public/private subnets, NAT Gateway, Internet Gateway, Security Group, and EC2 instances — all defined as code.

![Terraform](https://img.shields.io/badge/Terraform-v1.x-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-ap--south--1-FF9900?logo=amazonaws&logoColor=white)
![Status](https://img.shields.io/badge/Status-Complete-2ea44f)

---

## 📐 Architecture

```
                        Internet
                           │
                   Internet Gateway
                           │
          ┌────────────────┴──────────────────┐
          │          VPC: 10.0.0.0/16         │
          │                                   │
          │  ┌─────────────────────────────┐  │
          │  │    Public Subnet            │  │
          │  │    10.0.1.0/24              │  │
          │  │                             │  │
          │  │  Public Route Table ─► IGW  │  │
          │  │  NAT Gateway + Elastic IP   │  │
          │  │  Security Group (ec2-sg)    │  │
          │  │  EC2 × 3  (t3.micro)        │  │
          │  └─────────────────────────────┘  │
          │                │                  │
          │          (outbound only)          │
          │                │                  │
          │  ┌─────────────▼───────────────┐  │
          │  │    Private Subnet           │  │
          │  │    10.0.2.0/24              │  │
          │  │                             │  │
          │  │  Private Route Table ─► NAT │  │
          │  │  EC2 × 2  (t3.micro)        │  │
          │  │  No public IP               │  │
          │  └─────────────────────────────┘  │
          └───────────────────────────────────┘
```

---

## 📦 Resources Created

| Resource | Name | Details |
|---|---|---|
| VPC | `terraform-vpc` | CIDR: `10.0.0.0/16`, DNS hostnames enabled |
| Public Subnet | `public-subnet` | CIDR: `10.0.1.0/24`, auto-assign public IP |
| Private Subnet | `private-subnet` | CIDR: `10.0.2.0/24`, no public IP |
| Internet Gateway | `terraform-igw` | Attached to VPC |
| Elastic IP | `nat-eip` | Allocated for NAT Gateway |
| NAT Gateway | `NAT-gateway` | Lives in public subnet |
| Public Route Table | `public-route-table` | `0.0.0.0/0` → IGW |
| Private Route Table | `private-route-table` | `0.0.0.0/0` → NAT GW |
| Security Group | `ec2-sg` | Inbound: SSH (22), HTTP (80), HTTPS (443) |
| EC2 Instances (public) | `Terraform-EC2-1/2/3` | `t3.micro`, public subnet |
| EC2 Instances (private) | `Terraform-Private-EC2-1/2` | `t3.micro`, private subnet, no public IP |

**Total: 14 resources provisioned**

---

## 🛠️ Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed (v1.0+)
- AWS CLI configured with appropriate IAM permissions
- An existing EC2 Key Pair in `ap-south-1` (Mumbai region)
- AMI ID verified as available in `ap-south-1`

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/deepbijwe/AWS-projects.git
cd AWS-projects/terraform-vpc
```

### 2. Update variables in `vpc.tf`

Open `vpc.tf` and update the following values to match your environment:

```hcl
# Line ~157 — replace with your key pair name
key_name = "your-key-pair-name"

# Line ~121 — restrict to your IP in production
cidr_blocks = ["YOUR_IP/32"]

# Verify this AMI exists in ap-south-1
ami = "ami-07a00cf47dbbc844c"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Format and validate

```bash
terraform fmt
terraform validate
# Expected output: Success! The configuration is valid.
```

### 5. Preview the execution plan

```bash
terraform plan
```

Review the plan. You should see **14 resources** to be created.

### 6. Apply the configuration

```bash
terraform apply
```

Type `yes` when prompted. The NAT Gateway takes ~1–2 minutes to provision.

### 7. View outputs

After apply completes:

```
Outputs:

instance_public_ip   = ["3.x.x.x", "65.x.x.x", "13.x.x.x"]
vpc_id               = "vpc-xxxxxxxxxxxxxxxxx"
subnet_id            = "subnet-xxxxxxxxxxxxxxxxx"
private_subnet_id    = "subnet-xxxxxxxxxxxxxxxxx"
```

---

## 🗂️ File Structure

```
terraform-vpc/
├── vpc.tf        # All resources defined in a single file
└── README.md
```

---

## 🔍 Key Concepts Demonstrated

**Public vs Private subnet routing**
- Public subnet routes `0.0.0.0/0` directly through the Internet Gateway — instances get public IPs and can be reached from the internet.
- Private subnet routes `0.0.0.0/0` through the NAT Gateway — instances can initiate outbound connections (e.g. `apt update`) but are unreachable from the internet.

**NAT Gateway placement**
The NAT Gateway lives in the *public* subnet. It uses an Elastic IP to make outbound requests on behalf of private instances, then forwards responses back. The `depends_on` meta-argument ensures the Internet Gateway is fully attached before the NAT Gateway is created.

**`count` for multiple instances**
Using `count = 3` on the EC2 resource creates three identical instances. Each gets a unique name tag via `count.index + 1`, giving `Terraform-EC2-1`, `Terraform-EC2-2`, `Terraform-EC2-3`.

**Deprecated argument fix**
The older `vpc = true` argument on `aws_eip` was deprecated in recent AWS provider versions. This project uses the current syntax: `domain = "vpc"`.

---

## 🐛 Errors Encountered & Fixed By Me

| Error | Cause | Fix |
|---|---|---|
| `Unsupported argument "vpc"` on `aws_eip` | Old argument deprecated in AWS provider v6+ | Replaced with `domain = "vpc"` |
| Public subnet routing through NAT GW | Incorrect route table config | Set public RT gateway to IGW, not NAT |
| Splat operator `[*]` on non-count resources | VPC and subnets are single resources | Removed `[*]` from `vpc_id` and `subnet_id` outputs |

---

## 🧹 Cleanup

To avoid AWS charges, destroy all resources when done:

```bash
terraform destroy
```

Type `yes` when prompted. All 14 resources will be removed.

> ⚠️ NAT Gateways and Elastic IPs incur hourly charges even when idle. Always destroy when not in use.

---

## 📸 Project Screenshots

| Step | Description |
|---|---|
| `terraform init` | Provider initialized (hashicorp/aws v6.47.0) |
| `terraform validate` | Configuration valid |
| `terraform plan` | 14 resources planned |
| `terraform apply` | All 14 resources created successfully |

---

## 🔗 Connect

- GitHub: [deepbijwe](https://github.com/deepbijwe)
- Project Repo: [AWS-projects](https://github.com/deepbijwe/AWS-projects)

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).