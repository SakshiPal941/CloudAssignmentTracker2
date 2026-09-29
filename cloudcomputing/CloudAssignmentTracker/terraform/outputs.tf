output "rds_endpoint" {
  description = "Endpoint of the RDS PostgreSQL database"
  value       = aws_db_instance.postgres.endpoint
}