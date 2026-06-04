provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "deep_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.deep_vpc.id
  cidr_block              = var.public_cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.deep_vpc.id
  cidr_block              = var.private_cidr_block
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
