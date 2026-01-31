terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

###################
# VPC
###################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "webapp-vpc"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "webapp-igw"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "webapp-public-subnet"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "webapp-public-rt"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

###################
# Security Group
###################

resource "aws_security_group" "web" {
  name        = "webapp-security-group"
  description = "Security group for web servers (Apache and Nginx)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from Jenkins"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.jenkins_ip}/32"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "webapp-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

###################
# Key Pair
###################

resource "aws_key_pair" "deployer" {
  key_name   = "webserver-key"
  public_key = file(var.public_key_path)

  tags = {
    Name        = "webserver-deploy-key"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

###################
# EC2 Instances - Apache
###################

resource "aws_instance" "apache" {
  count                  = var.apache_instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name        = "apache-${count.index + 1}"
    ServerType  = "Apache"
    Environment = var.environment
    Project     = var.project_name
    Index       = count.index + 1
    ManagedBy   = "Terraform"
  }

  # Add a more descriptive volume tag
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    tags = {
      Name = "apache-${count.index + 1}-root-volume"
    }
  }
}

###################
# EC2 Instances - Nginx
###################

resource "aws_instance" "nginx" {
  count                  = var.nginx_instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name        = "nginx-${count.index + 1}"
    ServerType  = "Nginx"
    Environment = var.environment
    Project     = var.project_name
    Index       = count.index + 1
    ManagedBy   = "Terraform"
  }

  # Add a more descriptive volume tag
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    tags = {
      Name = "nginx-${count.index + 1}-root-volume"
    }
  }
}

###################
# Ansible Inventory File
###################

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible-playbooks/inventory/hosts.ini"

  content = templatefile("${path.module}/templates/inventory.tftpl", {
    apache_ips = aws_instance.apache[*].public_ip
    nginx_ips  = aws_instance.nginx[*].public_ip
  })

  depends_on = [
    aws_instance.apache,
    aws_instance.nginx
  ]
}
