provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "deep_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.deep_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.deep_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.deep_vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

# Public Route Table
# FIX #1: public subnet must route through IGW, not NAT Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.deep_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Route Table - Public Subnet Association
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Elastic IP for NAT Gateway
# FIX #2: replaced deprecated `vpc = true` with `domain = "vpc"`
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway (lives in public subnet)
# depends_on ensures IGW is attached before NAT GW is created
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.my_igw]

  tags = {
    Name = "NAT-gateway"
  }
}

# Private Route Table
# Private subnet routes outbound traffic through NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.deep_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Route Table - Private Subnet Association
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow SSH HTTP HTTPS"
  vpc_id      = aws_vpc.deep_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production: ["YOUR_IP/32"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# EC2 Instances
# Unique Name tag per instance using count.index
resource "aws_instance" "ec2" {
  count                  = 3
  ami                    = "ami-07a00cf47dbbc844c" # Verify this AMI exists in ap-south-1
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = "my-mumbai"

  tags = {
    Name = "Terraform-EC2-${count.index + 1}"
  }
}

#private instance in private subnet

resource "aws_instance" "private-ec2" {
  count                  = 2
  ami                    = "ami-07a00cf47dbbc844c" # Verify this AMI exists in ap-south-1
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = false
  key_name               = "my-mumbai"

  tags = {
    Name = "Terraform-Private-EC2-${count.index + 1}"
  }
}

# Outputs
output "instance_public_ip" {
  value = aws_instance.ec2[*].public_ip
}


# Removed unnecessary `[*]` splat — vpc and subnets are not count resources
output "vpc_id" {
  value = aws_vpc.deep_vpc.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

# NOTES:
# - Verify AMI ID is valid in ap-south-1 before applying
# - Update key_name to match your actual AWS key pair
# - Restrict SSH cidr_blocks to your IP in production
