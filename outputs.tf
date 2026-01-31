
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.web.id
}

output "apache_instance_ids" {
  description = "Apache EC2 Instance IDs"
  value       = aws_instance.apache[*].id
}

output "apache_public_ips" {
  description = "Apache Public IPs"
  value       = aws_instance.apache[*].public_ip
}

output "apache_urls" {
  description = "Apache URLs"
  value       = formatlist("http://%s", aws_instance.apache[*].public_ip)
}

output "nginx_instance_ids" {
  description = "Nginx EC2 Instance IDs"
  value       = aws_instance.nginx[*].id
}

output "nginx_public_ips" {
  description = "Nginx Public IPs"
  value       = aws_instance.nginx[*].public_ip
}

output "nginx_urls" {
  description = "Nginx URLs"
  value       = formatlist("http://%s", aws_instance.nginx[*].public_ip)
}


output "all_server_ips" {
  description = "All Server Public IPs"
  value = {
    apache = aws_instance.apache[*].public_ip
    nginx  = aws_instance.nginx[*].public_ip
  }
}

output "server_summary" {
  description = "Server Count Summary"
  value = {
    apache_count = var.apache_instance_count
    nginx_count  = var.nginx_instance_count
    total        = var.apache_instance_count + var.nginx_instance_count
  }
}
