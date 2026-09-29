# Private EC2 instance for the backend API
resource "aws_instance" "api" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id = aws_subnet.private_app.id

  vpc_security_group_ids = [
    aws_security_group.api.id
  ]

  user_data = <<-EOF
    #!/bin/bash

    apt-get update
    apt-get install -y git openjdk-17-jdk

    cd /opt

    git clone https://github.com/SakshiPal941/CloudAssignmentTracker2.git

    cd /opt/CloudAssignmentTracker2/cloudcomputing/CloudAssignmentTracker/Backend

    chmod +x mvnw

    export DB_HOST="${aws_db_instance.postgres.address}"
    export DB_NAME="${var.db_name}"
    export DB_USERNAME="${var.db_username}"
    export DB_PASSWORD="${var.db_password}"

    ./mvnw clean package -DskipTests

    nohup java -jar target/*.jar > /var/log/assignment-tracker.log 2>&1 &
  EOF

  tags = {
    Name = "cloud-assignment-api"
  }
}