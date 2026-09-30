# Latest Ubuntu 22.04 AMI (the user_data scripts use apt-get)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Private EC2 instance for the backend API
resource "aws_instance" "api" {
  ami           = data.aws_ami.ubuntu.id
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
  ami           = data.aws_ami.ubuntu.id
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
    apt-get install -y git nginx

    # Clone repository
    cd /opt
    git clone https://github.com/SakshiPal941/CloudAssignmentTracker2.git

    # Frontend is plain HTML/JS/CSS, so copy it straight to Nginx
    rm -rf /var/www/html/*
    cp -r /opt/CloudAssignmentTracker2/cloudcomputing/CloudAssignmentTracker/Frontend/* /var/www/html/

    # Configure Nginx to serve the frontend and proxy /api/ to the backend
    cat > /etc/nginx/sites-available/default <<'NGINX'
    server {
        listen 80;
        server_name _;

        root /var/www/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://${aws_instance.api.private_ip}:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
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
