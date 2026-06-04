# AWS Application Load Balancer with Terraform

> Provisioning an internet-facing ALB distributing traffic across two Ubuntu EC2 instances using Terraform — with real debugging errors and fixes documented.

---

## Architecture

```
                          Internet
                              │
                              ▼
                  ┌─────────────────────┐
                  │  Application Load   │
                  │     Balancer        │
                  │  (internet-facing)  │
                  │   Listener :80      │
                  └──────────┬──────────┘
                             │
               ┌─────────────▼─────────────┐
               │        Target Group        │
               │   Health check: GET /      │
               └──────┬────────────┬────────┘
                      │            │
            ┌─────────▼──┐    ┌────▼────────┐
            │  EC2 web-1  │    │  EC2 web-2  │
            │ ap-south-1a │    │ ap-south-1b │
            │  Apache2    │    │  Apache2    │
            │  Port 80    │    │  Port 80    │
            └─────────────┘    └─────────────┘
                      │            │
            ┌─────────▼────────────▼────────┐
            │              VPC              │
            │        10.0.0.0/16            │
            │  Public Subnet 1  Subnet 2    │
            └───────────────────────────────┘
```

---

## Tech Stack

| Tool        | Purpose                          |
|-------------|----------------------------------|
| Terraform   | Infrastructure as Code           |
| AWS ALB     | Load balancing across 2 EC2s     |
| AWS EC2     | Ubuntu 22.04 web servers         |
| Apache2     | HTTP server on each instance     |
| AWS VPC     | Isolated network environment     |
| Custom HTML | Netflix-style login page via `user_data` |

---

## Project Structure

```
alb-project/
├── main.tf           # All AWS resources
├── variables.tf      # Input variables
├── outputs.tf        # ALB DNS and instance IPs
└── terraform.tfvars  # Variable values (optional)
```

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.0 installed
- An existing EC2 key pair in `ap-south-1`

---

## Terraform Files

### `variables.tf`

```hcl
variable "region" {
  default = "ap-south-1"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS - Mumbai region"
  default     = "ami-0f58b397bc5c1f2e8"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Your existing EC2 key pair name"
  default     = "my-key"
}
```

> To get the latest Ubuntu 22.04 AMI ID for Mumbai:
> ```bash
> aws ec2 describe-images \
>   --region ap-south-1 \
>   --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
>             "Name=state,Values=available" \
>   --query "sort_by(Images, &CreationDate)[-1].ImageId" \
>   --output text
> ```

---

### `main.tf`

```hcl
provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "alb-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "alb-igw" }
}

# Public Subnets (2 AZs — ALB requires minimum 2)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-2" }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group — ALB
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

# Security Group — EC2
resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-sg" }
}

# EC2 Instance 1
resource "aws_instance" "web1" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y apache2
    systemctl start apache2
    systemctl enable apache2
    cat > /var/www/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      <title>Netflix – Sign In</title>
      <link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Barlow:wght@300;400;500;600;700&display=swap" rel="stylesheet"/>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
          --red: #e50914; --red-dark: #b81d24; --dark: #141414;
          --input-bg: #333; --input-focus: #454545; --gray: #8c8c8c;
          --light: #e5e5e5; --white: #fff; --error: #e87c03;
        }
        body { font-family: "Barlow", sans-serif; background: var(--dark); color: var(--white); min-height: 100vh; display: flex; flex-direction: column; }
        .bg { position: fixed; inset: 0; background: url("https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=1600&q=80") center/cover no-repeat; z-index: 0; }
        .bg-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 1; }
        nav { position: relative; z-index: 10; padding: 24px 48px; display: flex; align-items: center; justify-content: space-between; }
        .logo { font-family: "Bebas Neue", sans-serif; font-size: 2.4rem; color: var(--red); letter-spacing: 3px; text-decoration: none; }
        main { position: relative; z-index: 10; flex: 1; display: flex; align-items: center; justify-content: center; padding: 40px 20px; }
        .card { background: rgba(0,0,0,0.75); border-radius: 6px; padding: 60px 68px 70px; width: 100%; max-width: 450px; }
        .card h1 { font-size: 2rem; font-weight: 700; margin-bottom: 28px; }
        .form-group { position: relative; margin-bottom: 16px; }
        .form-group input { width: 100%; background: var(--input-bg); border: none; border-radius: 4px; padding: 24px 16px 8px; color: var(--white); font-size: 16px; outline: none; }
        .form-group label { position: absolute; left: 16px; top: 50%; transform: translateY(-50%); color: var(--gray); font-size: 16px; pointer-events: none; transition: top 0.15s, font-size 0.15s; }
        .form-group input:focus + label, .form-group input:not(:placeholder-shown) + label { top: 10px; font-size: 11px; transform: none; }
        .btn-signin { width: 100%; background: var(--red); color: var(--white); border: none; border-radius: 4px; padding: 16px; font-size: 16px; font-weight: 700; cursor: pointer; margin-bottom: 20px; }
        .btn-signin:hover { background: var(--red-dark); }
        .signup-row { font-size: 15px; color: var(--gray); }
        .signup-row a { color: var(--white); text-decoration: none; font-weight: 600; }
        .instance-badge { margin-top: 20px; background: rgba(229,9,20,0.15); border: 1px solid var(--red); border-radius: 4px; padding: 10px 16px; font-size: 13px; color: var(--red); text-align: center; letter-spacing: 1px; }
        footer { position: relative; z-index: 10; background: rgba(0,0,0,0.75); border-top: 1px solid #333; padding: 30px 48px; }
        .footer-links { display: flex; flex-wrap: wrap; gap: 10px 24px; margin-bottom: 14px; }
        .footer-links a { color: #737373; font-size: 12px; text-decoration: none; }
        .footer-copy { color: #737373; font-size: 12px; }
      </style>
    </head>
    <body>
    <div class="bg"></div>
    <div class="bg-overlay"></div>
    <nav><a class="logo" href="#">NETFLIX</a></nav>
    <main>
      <div class="card">
        <h1>Sign In</h1>
        <div class="form-group">
          <input type="text" id="email" placeholder=" "/>
          <label for="email">Email or phone number</label>
        </div>
        <div class="form-group">
          <input type="password" id="password" placeholder=" "/>
          <label for="password">Password</label>
        </div>
        <button class="btn-signin">Sign In</button>
        <div class="signup-row">New to Netflix? <a href="#">Sign up now.</a></div>
        <div class="instance-badge">⚡ Served by Instance 1 — ap-south-1a</div>
      </div>
    </main>
    <footer>
      <div class="footer-links">
        <a href="#">FAQ</a><a href="#">Help Centre</a>
        <a href="#">Terms of Use</a><a href="#">Privacy</a>
      </div>
      <p class="footer-copy">Netflix India</p>
    </footer>
    </body>
    </html>
    HTML
  EOF

  tags = { Name = "web-server-1" }
}

# EC2 Instance 2
resource "aws_instance" "web2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y apache2
    systemctl start apache2
    systemctl enable apache2
    cat > /var/www/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      <title>Netflix – Sign In</title>
      <link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Barlow:wght@300;400;500;600;700&display=swap" rel="stylesheet"/>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
          --red: #e50914; --red-dark: #b81d24; --dark: #141414;
          --input-bg: #333; --input-focus: #454545; --gray: #8c8c8c;
          --light: #e5e5e5; --white: #fff; --error: #e87c03;
        }
        body { font-family: "Barlow", sans-serif; background: var(--dark); color: var(--white); min-height: 100vh; display: flex; flex-direction: column; }
        .bg { position: fixed; inset: 0; background: url("https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=1600&q=80") center/cover no-repeat; z-index: 0; }
        .bg-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 1; }
        nav { position: relative; z-index: 10; padding: 24px 48px; display: flex; align-items: center; justify-content: space-between; }
        .logo { font-family: "Bebas Neue", sans-serif; font-size: 2.4rem; color: var(--red); letter-spacing: 3px; text-decoration: none; }
        main { position: relative; z-index: 10; flex: 1; display: flex; align-items: center; justify-content: center; padding: 40px 20px; }
        .card { background: rgba(0,0,0,0.75); border-radius: 6px; padding: 60px 68px 70px; width: 100%; max-width: 450px; }
        .card h1 { font-size: 2rem; font-weight: 700; margin-bottom: 28px; }
        .form-group { position: relative; margin-bottom: 16px; }
        .form-group input { width: 100%; background: var(--input-bg); border: none; border-radius: 4px; padding: 24px 16px 8px; color: var(--white); font-size: 16px; outline: none; }
        .form-group label { position: absolute; left: 16px; top: 50%; transform: translateY(-50%); color: var(--gray); font-size: 16px; pointer-events: none; transition: top 0.15s, font-size 0.15s; }
        .form-group input:focus + label, .form-group input:not(:placeholder-shown) + label { top: 10px; font-size: 11px; transform: none; }
        .btn-signin { width: 100%; background: var(--red); color: var(--white); border: none; border-radius: 4px; padding: 16px; font-size: 16px; font-weight: 700; cursor: pointer; margin-bottom: 20px; }
        .btn-signin:hover { background: var(--red-dark); }
        .signup-row { font-size: 15px; color: var(--gray); }
        .signup-row a { color: var(--white); text-decoration: none; font-weight: 600; }
        .instance-badge { margin-top: 20px; background: rgba(229,9,20,0.15); border: 1px solid var(--red); border-radius: 4px; padding: 10px 16px; font-size: 13px; color: var(--red); text-align: center; letter-spacing: 1px; }
        footer { position: relative; z-index: 10; background: rgba(0,0,0,0.75); border-top: 1px solid #333; padding: 30px 48px; }
        .footer-links { display: flex; flex-wrap: wrap; gap: 10px 24px; margin-bottom: 14px; }
        .footer-links a { color: #737373; font-size: 12px; text-decoration: none; }
        .footer-copy { color: #737373; font-size: 12px; }
      </style>
    </head>
    <body>
    <div class="bg"></div>
    <div class="bg-overlay"></div>
    <nav><a class="logo" href="#">NETFLIX</a></nav>
    <main>
      <div class="card">
        <h1>Sign In</h1>
        <div class="form-group">
          <input type="text" id="email" placeholder=" "/>
          <label for="email">Email or phone number</label>
        </div>
        <div class="form-group">
          <input type="password" id="password" placeholder=" "/>
          <label for="password">Password</label>
        </div>
        <button class="btn-signin">Sign In</button>
        <div class="signup-row">New to Netflix? <a href="#">Sign up now.</a></div>
        <div class="instance-badge">⚡ Served by Instance 2 — ap-south-1b</div>
      </div>
    </main>
    <footer>
      <div class="footer-links">
        <a href="#">FAQ</a><a href="#">Help Centre</a>
        <a href="#">Terms of Use</a><a href="#">Privacy</a>
      </div>
      <p class="footer-copy">Netflix India</p>
    </footer>
    </body>
    </html>
    HTML
  EOF

  tags = { Name = "web-server-2" }
}

# Target Group
resource "aws_lb_target_group" "my_tg" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = { Name = "my-tg" }
}

# Register EC2 instances to Target Group
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# Application Load Balancer
resource "aws_lb" "my_alb" {
  name               = "my-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = { Name = "my-app-alb" }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}
```

---

### `outputs.tf`

```hcl
output "alb_dns_name" {
  description = "Open this URL in browser to test load balancing"
  value       = aws_lb.my_alb.dns_name
}

output "instance_1_public_ip" {
  value = aws_instance.web1.public_ip
}

output "instance_2_public_ip" {
  value = aws_instance.web2.public_ip
}
```

---

## Custom Page via `user_data`

Instead of a plain HTML response, a custom Netflix-style login page is embedded directly into the `user_data` script using a heredoc (`cat > /var/www/html/index.html <<'HTML' ... HTML`). This is the cleanest way to inject multi-line HTML into `user_data` without breaking the bash script.

Each instance serves the same page but with a different badge at the bottom — **Instance 1 — ap-south-1a** and **Instance 2 — ap-south-1b** — so you can visually confirm the ALB is round-robining traffic between both instances on every browser refresh.

> **`user_data` size limit is 16KB.** For larger pages with external assets, upload the HTML to S3 and pull it on boot:
> ```bash
> aws s3 cp s3://your-bucket/index.html /var/www/html/index.html
> ```

> **Single quotes inside `user_data`:** The heredoc delimiter `'HTML'` (quoted) prevents bash from interpreting `$variables` and special characters inside the HTML — safe to use inline CSS and JS without escaping.

---

## Deployment Steps

**Step 1 — Clone and enter the project directory**

```bash
git clone https://github.com/deepbijwe/Terraform-projets
cd Terraform-projects/Terraform-ALB
```

**Step 2 — Initialize Terraform**

```bash
terraform init
```

**Step 3 — Preview the plan**

```bash
terraform plan
```

**Step 4 — Apply the infrastructure**

```bash
terraform apply
```

Type `yes` when prompted. Takes about 2-3 minutes.

**Step 5 — Note the output**

```
alb_dns_name = "my-app-alb-1234567890.ap-south-1.elb.amazonaws.com"
```

**Step 6 — Test in browser**

Open the ALB DNS URL in your browser and keep refreshing — you will see the response alternate between **Instance 1** and **Instance 2** as the ALB round-robins traffic.

**Step 7 — Destroy when done**

```bash
terraform destroy
```

---

## Errors Encountered & Fixes

### Error 1 — Wrong package manager in `user_data`

**Problem:** The initial `user_data` script used `yum` (Amazon Linux package manager) on Ubuntu instances. Apache2 never got installed so the web server was never running.

```bash
# WRONG — yum does not exist on Ubuntu
yum install -y httpd
systemctl start httpd
```

**Fix:** Ubuntu uses `apt` and the service name is `apache2` not `httpd`.

```bash
# CORRECT — for Ubuntu
apt-get install -y apache2
systemctl start apache2
```

---

### Error 2 — Target group showing unhealthy

**Problem:** After fixing the `user_data`, the target group was still showing instances as unhealthy in the AWS console.

**Root cause:** The EC2 security group had the port 80 ingress rule set to allow traffic only from the ALB security group (`security_groups = [alb_sg.id]`). While this is the recommended secure pattern, the ALB health check probes were not reaching the instances.

**Debugging steps performed:**

```bash
# SSH into instance
ssh -i my-key.pem ubuntu@<instance-public-ip>

# Check if apache2 was running
sudo systemctl status apache2

# Test local response
curl localhost
# Returned: <h1>Hello from Instance 1</h1> ✅
```

Apache2 was running fine. The issue was confirmed to be the security group rule blocking the health check probes.

**Fix:** Updated the EC2 security group ingress rule to allow port 80 from `0.0.0.0/0`.

```hcl
# Updated ingress rule in ec2_sg
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]   # Allow from anywhere
}
```

After this change the target group showed both instances as **healthy** within 2 minutes (health check interval is 30s, needs 3 consecutive successes).

---

### Error 3 — `user_data` changes not reflected on existing instances

**Problem:** After fixing the `user_data` script in `main.tf` and running `terraform apply`, the running instances were not updated because `user_data` only executes on first boot.

**Fix:** Tainted both instances to force recreation with the corrected script.

```bash
terraform taint aws_instance.web1
terraform taint aws_instance.web2
terraform apply
```

---

## Key Learnings

- ALB requires subnets in **at least 2 different Availability Zones**
- Ubuntu uses `apt` and `apache2` — not `yum` and `httpd` (Amazon Linux)
- `user_data` only runs on **first boot** — use `terraform taint` to force recreation after changes
- ALB health checks need port 80 accessible from the ALB to EC2 — verify security group rules first when targets show unhealthy
- Always verify with `curl localhost` inside the instance before blaming the load balancer
- Use `cat > /var/www/html/index.html <<'HTML' ... HTML` heredoc syntax to safely embed full HTML pages in `user_data` — the quoted delimiter prevents bash from interpreting `$variables` inside the HTML
- `user_data` has a **16KB size limit** — for larger pages, host on S3 and pull on boot

---

## Result

Both EC2 instances registered as healthy in the target group. The ALB DNS distributes traffic across both instances using round-robin. Refreshing the browser loads the Netflix-style login page and alternates the instance badge between **Instance 1 — ap-south-1a** and **Instance 2 — ap-south-1b**, confirming the ALB is correctly distributing traffic.

---

## Author

**Deep Bijwe**
- GitHub: [@deepbijwe](https://github.com/deepbijwe)
- LinkedIn: [linkedin.com/in/deepbijwe](https://linkedin.com/in/deepbijwe)

---

*Part of my AWS Projects series — hands-on cloud infrastructure built and documented from scratch.*