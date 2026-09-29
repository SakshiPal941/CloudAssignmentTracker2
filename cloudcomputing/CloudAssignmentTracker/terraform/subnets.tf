# Creates the subnets inside our VPC

# Public subnet for the frontend
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "cloud-assignment-public-subnet"
  }
}

# Private subnet for the backend/API
resource "aws_subnet" "private_app" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "cloud-assignment-private-app-subnet"
  }
}

# Private subnet for the database
resource "aws_subnet" "private_db" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "cloud-assignment-private-db-subnet"
  }
}