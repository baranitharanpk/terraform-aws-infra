# outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web.id
}

# ---------------- APACHE ----------------

output "apache_instance_ids" {
  description = "List of Apache EC2 instance IDs"
  value       = aws_instance.apache[*].id
}

output "apache_public_ips" {
  description = "List of Apache server public IP addresses"
  value       = aws_instance.apache[*].public_ip
}

output "apache_private_ips" {
  description = "List of Apache server private IP addresses"
  value       = aws_instance.apache[*].private_ip
}

output "apache_urls" {
  description = "URLs to access Apache servers"
  value       = formatlist("http://%s", aws_instance.apache[*].public_ip)
}

# ---------------- NGINX ----------------

output "nginx_instance_ids" {
  description = "List of Nginx EC2 instance IDs"
  value       = aws_instance.nginx[*].id
}

output "nginx_public_ips" {
  description = "List of Nginx server public IP addresses"
  value       = aws_instance.nginx[*].public_ip
}

output "nginx_private_ips" {
  description = "List of Nginx server private IP addresses"
  value       = aws_instance.nginx[*].private_ip
}

output "nginx_urls" {
  description = "URLs to access Nginx servers"
  value       = formatlist("http://%s", aws_instance.nginx[*].public_ip)
}

# ---------------- COMBINED ----------------

output "all_server_ips" {
  description = "All server IP addresses"
  value = {
    apache = aws_instance.apache[*].public_ip
    nginx  = aws_instance.nginx[*].public_ip
  }
}

output "all_server_urls" {
  description = "All server URLs"
  value = concat(
    formatlist("http://%s (Apache)", aws_instance.apache[*].public_ip),
    formatlist("http://%s (Nginx)", aws_instance.nginx[*].public_ip)
  )
}

output "server_summary" {
  description = "Summary of all servers"
  value = {
    total_apache_servers = var.apache_instance_count
    total_nginx_servers  = var.nginx_instance_count
    total_servers        = var.apache_instance_count + var.nginx_instance_count
  }
}

# -------- REQUIRED FOR JENKINS / DEBUG --------

output "ansible_inventory_content" {
  description = "Rendered Ansible inventory file content"
  value       = local_file.ansible_inventory.content
}
