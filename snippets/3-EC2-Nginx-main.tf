terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.32.1"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.2.1"
    }
    local = {
      source = "hashicorp/local"
      version = "2.7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "public_key" {
  key_name   = "visualizer-key"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "viskey" {
  content  = tls_private_key.private_key.private_key_pem
  filename = "${path.module}/viskey.pem"
  file_permission = "0600"
}

# --- VPC ---
resource "aws_vpc" "visualizer_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "visualizerVPC" }
}

# --- Subnets ---
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.visualizer_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "PublicSubnet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.visualizer_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = { Name = "PrivateSubnet" }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.visualizer_vpc.id
  tags   = { Name = "VisualizerIGW" }
}

# --- NAT Gateway ---
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags          = { Name = "VisualizerNAT" }
}

# --- Route Tables ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.visualizer_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "PublicRouteTable" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.visualizer_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "PrivateRouteTable" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# --- Security Groups ---
resource "aws_security_group" "nginx_sg" {
  name   = "nginx-sg"
  vpc_id = aws_vpc.visualizer_vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
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
}

resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = aws_vpc.visualizer_vpc.id

  ingress {
    description = "Allow traffic from Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.nginx_sg.id]
  }

  ingress {
    description = "Allow SSH from Nginx"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.nginx_sg.id]
  }

    ingress {
    description = "Allow port 5000 to Nginx"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    security_groups = [aws_security_group.nginx_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Instances ---
resource "aws_instance" "nginx_ec2" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.nginx_sg.id]
  associate_public_ip_address = true
  tags = { Name = "NginxEC2" }
}

resource "aws_instance" "app_ec2" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t3.micro"
  count                       = 2
  subnet_id                   = aws_subnet.private_subnet.id
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false
  tags = { Name = "AppEC2" }
}

output "nginx_public_ip" {
  value = aws_instance.nginx_ec2.public_ip
}

output "app_private_ips" {
  value = aws_instance.app_ec2[*].private_ip
}
