output "alb_dns_name" {
  description = "Hit this URL in browser to test"
  value       = aws_lb.my_alb.dns_name
}

output "instance_1_public_ip" {
  value = aws_instance.web1.public_ip
}

output "instance_2_public_ip" {
  value = aws_instance.web2.public_ip
}