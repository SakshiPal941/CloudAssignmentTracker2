# API server
resource "aws_instance" "api" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id = aws_subnet.private_app.id

  vpc_security_group_ids = [
    aws_security_group.api.id
  ]

  tags = {
    Name = "cloud-assignment-api"
  }
}

