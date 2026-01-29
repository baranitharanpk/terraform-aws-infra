# main.tf
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
# VPC Configuration
###################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "devops-vpc"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devops-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "devops-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "devops-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

###################
# Security Groups
###################

resource "aws_security_group" "web" {
  name        = "web-server-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # HTTP Access
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS Access
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH from Jenkins server only
  ingress {
    description = "SSH from Jenkins"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.jenkins_ip}/32"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

###################
# SSH Key Pair
###################

resource "aws_key_pair" "deployer" {
  key_name   = "webserver-key"
  public_key = file(var.public_key_path)

  tags = {
    Name = "webserver-deploy-key"
  }
}

###################
# EC2 Instances
###################

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public.id

  # User data script to prepare the instance
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              apt-get update
              apt-get upgrade -y
              
              # Install nginx
              apt-get install -y nginx
              
              # Install Python for Ansible
              apt-get install -y python3 python3-pip
              
              # Start and enable nginx
              systemctl start nginx
              systemctl enable nginx
              
              # Create a placeholder page
              echo "<h1>Server ${count.index + 1} - Ready for deployment</h1>" > /var/www/html/index.html
              
              # Log completion
              echo "Setup completed at $(date)" >> /var/log/user-data.log
              EOF

  tags = {
    Name        = "webserver-${count.index + 1}"
    Role        = "webserver"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  # Ensure instance is fully initialized
  lifecycle {
    create_before_destroy = true
  }
}

###################
# Generate Ansible Inventory
###################

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    webservers = aws_instance.web[*].public_ip
  })
  filename = "${path.module}/../ansible-playbooks/inventory/hosts.ini"

  # Only create after instances are ready
  depends_on = [aws_instance.web]
}

###################
# Output Summary File
###################

resource "local_file" "deployment_summary" {
  content = <<-EOF
  ========================================
  DEPLOYMENT SUMMARY
  ========================================
  Deployment Time: ${timestamp()}
  Region: ${var.aws_region}
  VPC ID: ${aws_vpc.main.id}
  Subnet ID: ${aws_subnet.public.id}
  
  Web Servers (${var.instance_count}):
  ${join("\n  ", formatlist("- %s (Instance: %s)", aws_instance.web[*].public_ip, aws_instance.web[*].id))}
  
  Access URLs:
  ${join("\n  ", formatlist("- http://%s", aws_instance.web[*].public_ip))}
  
  SSH Access:
  ${join("\n  ", formatlist("ssh -i ~/.ssh/webserver-key ubuntu@%s", aws_instance.web[*].public_ip))}
  ========================================
  EOF
  
  filename = "${path.module}/deployment-summary.txt"
}
