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

# Public EC2 instance for the frontend
resource "aws_instance" "frontend" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.frontend.id
  ]

  associate_public_ip_address = true

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update
    apt-get install -y git nginx curl

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs

    # Clone repository
    cd /opt
    git clone https://github.com/SakshiPal941/CloudAssignmentTracker2.git

    # Frontend directory
    cd /opt/CloudAssignmentTracker2/cloudcomputing/cloudassignmenttracker/Frontend

    # Install dependencies and build
    npm install
    npm run build

    # Copy built frontend to Nginx
    rm -rf /var/www/html/*
    cp -r dist/* /var/www/html/

    # Configure Nginx
    cat > /etc/nginx/sites-available/default <<'NGINX'
    server {
        listen 80;
        server_name _;

        root /var/www/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }
    }
    NGINX

    # Make sure Nginx is running
    nginx -t
    systemctl enable nginx
    systemctl restart nginx
  EOF

  tags = {
    Name = "cloud-assignment-frontend"
  }
}