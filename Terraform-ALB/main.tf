provider "aws" {
  region = var.region
}

# ─── VPC ────────────────────────────────────────────────────────
resource "aws_vpc" "My_VPC" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "Alb-vpc" }
}

# ─── Internet Gateway ───────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.My_VPC.id
  tags   = { Name = "Alb-igw" }
}

# ─── Subnets (2 different AZs — ALB requires this) ─────────────
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.My_VPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.My_VPC.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-2" }
}

# ─── Route Table ────────────────────────────────────────────────
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.My_VPC.id
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

# ─── Security Group for ALB ─────────────────────────────────────
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.My_VPC.id

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

# ─── Security Group for EC2 ─────────────────────────────────────

resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.My_VPC.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# ─── EC2 Instances ──────────────────────────────────────────────
resource "aws_instance" "web1" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Instance 1</h1>" > /var/www/html/index.html
  EOF

  tags = { Name = "web-server-1" }
}

resource "aws_instance" "web2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Instance 2</h1>" > /var/www/html/index.html
  EOF

  tags = { Name = "web-server-2" }
}

# ─── Target Group ───────────────────────────────────────────────
resource "aws_lb_target_group" "my_tg" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.My_VPC.id

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

# ─── Register both EC2s to Target Group ─────────────────────────
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

# ─── Application Load Balancer ──────────────────────────────────
resource "aws_lb" "my_alb" {
  name               = "my-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = { Name = "my-app-alb" }
}

# ─── Listener ───────────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}