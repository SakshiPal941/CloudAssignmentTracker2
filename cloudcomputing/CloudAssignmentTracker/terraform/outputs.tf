output "rds_endpoint" {
  description = "Endpoint of the RDS PostgreSQL database"
  value       = aws_db_instance.postgres.endpoint
}
output "frontend_public_ip" {
  description = "Public IP of the frontend EC2 instance"
  value       = aws_instance.frontend.public_ip
}
