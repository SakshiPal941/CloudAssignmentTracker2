# Managed PostgreSQL database

resource "aws_db_subnet_group" "database" {
  name = "cloud-assignment-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_db.id,
    aws_subnet.private_db_b.id
  ]

  tags = {
    Name = "cloud-assignment-db-subnet-group"
  }
}

# Managed PostgreSQL database
resource "aws_db_instance" "postgres" {
  identifier = "cloud-assignment-database"

  engine         = "postgres"
  engine_version = "17"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "cloud-assignment-postgres"
  }
}