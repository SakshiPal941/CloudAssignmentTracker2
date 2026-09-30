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

  # Fixed private IP so the frontend's Nginx proxy target stays the same
  # when the backend is rebuilt
  private_ip = "10.0.2.10"

  vpc_security_group_ids = [
    aws_security_group.api.id
  ]

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    # Send all output to a log file and the EC2 system log for troubleshooting
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
    set -eux

    export HOME=/root
    export DEBIAN_FRONTEND=noninteractive

    # Add swap so the Maven build doesn't run out of memory on a t2.micro
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # Wait for Ubuntu's automatic updates to release the apt lock
    apt-get -o DPkg::Lock::Timeout=300 update
    apt-get -o DPkg::Lock::Timeout=300 install -y git openjdk-17-jdk

    # Clone and build the backend
    git clone https://github.com/SakshiPal941/CloudAssignmentTracker2.git /opt/CloudAssignmentTracker2
    cd /opt/CloudAssignmentTracker2/cloudcomputing/CloudAssignmentTracker/Backend
    chmod +x mvnw
    ./mvnw -B clean package -DskipTests
    cp target/*.jar /opt/assignment-tracker.jar

    # Database settings, readable only by root
    cat > /etc/assignment-tracker.env <<'ENV'
    DB_HOST=${aws_db_instance.postgres.address}
    DB_NAME=${var.db_name}
    DB_USERNAME=${var.db_username}
    DB_PASSWORD=${var.db_password}
    ENV
    chmod 600 /etc/assignment-tracker.env

    # Run the backend as a service so it starts again after a reboot
    cat > /etc/systemd/system/assignment-tracker.service <<'UNIT'
    [Unit]
    Description=Assignment Tracker backend
    After=network-online.target
    Wants=network-online.target

    [Service]
    EnvironmentFile=/etc/assignment-tracker.env
    ExecStart=/usr/bin/java -jar /opt/assignment-tracker.jar
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now assignment-tracker
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
