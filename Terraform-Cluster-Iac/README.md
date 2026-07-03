# 🚀 EKS Cluster on Ubuntu AMI — Terraform

Deploy a production-ready **Amazon EKS cluster** with **Ubuntu worker nodes** in `ap-south-1` using modular Terraform.

---

## 📁 Project Structure

```
eks-cluster/
├── main.tf               # Root module — wires VPC + EKS together
├── provider.tf           # AWS provider + Terraform version constraints
├── variables.tf          # Input variable declarations
├── outputs.tf            # Cluster endpoint, name, kubeconfig command
├── terraform.tfvars      # Your actual variable values
└── modules/
    ├── vpc/
    │   ├── main.tf       # VPC, subnets, IGW, NAT GW, route tables
    │   ├── variables.tf
    │   └── outputs.tf
    └── eks/
        ├── main.tf       # IAM roles, EKS cluster, node group, launch template
        ├── variables.tf
        └── outputs.tf
```

---

## 🏗️ What Gets Created

| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16`, DNS enabled |
| Public Subnets | 2x across `ap-south-1a` / `ap-south-1b` |
| Private Subnets | 2x — EKS nodes live here |
| Internet Gateway | For public subnet outbound traffic |
| NAT Gateway | Allows private nodes to pull images |
| EKS Cluster | Kubernetes `1.30`, public + private API access |
| Node Group | 1x `t3.medium`, **Ubuntu 22.04** AMI (Canonical) |
| IAM Roles | EKS cluster role + worker node role with required policies |
| Launch Template | Bootstraps Ubuntu nodes into the cluster automatically |

---

## ⚙️ Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform `>= 1.6.0`
- IAM permissions: EKS, EC2, VPC, IAM

---

## 🚀 Deploy

```bash
# 1. Initialize
terraform init

# 2. Preview changes
terraform plan

# 3. Deploy (takes ~12–15 mins for EKS)
terraform apply

# 4. Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name eks-dev-cluster

# 5. Verify nodes
kubectl get nodes
```

---

## 🔑 Key Design Decisions

### Ubuntu AMI via Launch Template
EKS managed node groups support Ubuntu through a **custom AMI + launch template** pattern. The `user_data` script runs `/etc/eks/bootstrap.sh` which registers the node with the control plane.

### Private Node Placement
Worker nodes are placed in **private subnets** and reach the internet via NAT Gateway — a security best practice. The EKS API endpoint is accessible both publicly (for `kubectl`) and privately.

### Subnet Tagging
Subnets are tagged with `kubernetes.io/cluster/<name>` and `kubernetes.io/role/elb` / `kubernetes.io/role/internal-elb` — required for EKS to auto-discover subnets when creating LoadBalancer services.

---

## 🧹 Destroy

```bash
terraform destroy
```

---

## 💡 Optional: Enable S3 Remote Backend

Uncomment the `backend "s3"` block in `provider.tf` and set your bucket name — great for team use.

---

## 📌 Variables Reference

| Variable | Default | Description |
|---|---|---|
| `project_name` | `eks-dev` | Prefix for all resources |
| `region` | `ap-south-1` | AWS region |
| `cluster_version` | `1.30` | Kubernetes version |
| `node_instance_type` | `c7i-flex.large` | Worker node size |
| `node_desired_size` | `1` | Number of nodes |
