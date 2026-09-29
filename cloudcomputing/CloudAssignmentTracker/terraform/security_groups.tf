# Controls which resources are allowed to communicate with each other

# Security group for the frontend EC2 instance
resource "aws_security_group" "frontend" {
  name        = "cloud-assignment-frontend"
  description = "Allow web traffic to the frontend"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from the internet
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow the frontend to make outbound connections
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-assignment-frontend-sg"
  }
}

# Security group for the backend/API EC2 instance
resource "aws_security_group" "api" {
  name        = "cloud-assignment-api"
  description = "Allow traffic from the frontend"
  vpc_id      = aws_vpc.main.id

  # Allow API traffic from the frontend security group
  ingress {
    description     = "API from frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # Allow the API to make outbound connections
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-assignment-api-sg"
  }
}

# Security group for the PostgreSQL database
resource "aws_security_group" "database" {
  name        = "cloud-assignment-database"
  description = "Allow PostgreSQL traffic from the API"
  vpc_id      = aws_vpc.main.id

  # Allow PostgreSQL only from the API security group
  ingress {
    description     = "PostgreSQL from API"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  # Allow database responses
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-assignment-database-sg"
  }
}