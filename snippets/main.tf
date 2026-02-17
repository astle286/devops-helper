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

resource "aws_vpc" "visualizer_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "visualizerVPC"
  }
}

resource "aws_subnet" "visualizer_subnet" {
  vpc_id            = aws_vpc.visualizer_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "VisualizerSubnet"
  }
}

resource "aws_internet_gateway" "vis_gw" {
  vpc_id = aws_vpc.visualizer_vpc.id

  tags = {
    Name = "VisualizerIGW"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.visualizer_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vis_gw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.visualizer_subnet.id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "visualizer_sg" {
  name        = "visualizer-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.visualizer_vpc.id

  ingress {
    description = "SSH from anywhere"
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

  tags = {
    Name = "VisualizerSG"
  }
}


resource "aws_instance" "visualizer_ec2" {
  instance_type = "t3.micro"
  ami = "ami-0b6c6ebed2801a5cb"
  subnet_id = aws_subnet.visualizer_subnet.id
  key_name = aws_key_pair.public_key.key_name
  vpc_security_group_ids = [aws_security_group.visualizer_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "VisualizerEC2"
  }
}

output "public_ip" {
  value = aws_instance.visualizer_ec2.public_ip
}
