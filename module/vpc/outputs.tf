# Output del VPC ID
output "vpc_id" {
  description = "ID del VPC"
  value       = aws_vpc.this.id
}

# Output de las subnets públicas
output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = aws_subnet.public[*].id
}

# Output de las subnets privadas
output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = aws_subnet.private[*].id
}

# Output de la NAT Instance ID (solo si se habilita)
output "nat_instance_id" {
  description = "ID de la NAT Instance"
  value       = aws_instance.nat[*].id
}

# Output del Security Group de la NAT Instance (solo si se habilita)
output "nat_instance_security_group_id" {
  description = "ID del Security Group de la NAT Instance"
  value       = aws_security_group.nat_instance_sg[*].id
} 

# Output del Elastic IP del NAT Gateway (solo si se habilita)
output "nat_gateway_eip" {
  description = "Elastic IP del NAT Gateway"
  value       = aws_eip.nat[*].public_ip
}

# Output del NAT Gateway ID (solo si se habilita)
output "nat_gateway_id" {
  description = "ID del NAT Gateway"
  value       = aws_nat_gateway.nat_gw[*].id
}
