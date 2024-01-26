provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "security_group" {
  name        = "security-group"
  description = "Security group for Geth node"

  ingress {
    from_port   = 8545
    to_port     = 8545
    protocol    = "tcp"
    description = "web3 http port"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8546
    to_port     = 8546
    protocol    = "tcp"
    description = "web3 websocket port"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    description = "Ethereum geth node p2p port"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "iam_role" {
  name = "iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "cloudwatch-logs-policy"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          Effect   = "Allow",
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = aws_iam_role.iam_role.name
}

# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "log_group" {
  name              = "log-group"
  retention_in_days = 7
}

resource "aws_instance" "instance" {
  ami           = "ami-aa2ea6d0"
  instance_type = "t2.medium"
  count         = 1
  key_name      = "YOUR-KEY-PAIR" # ENTER YOUR KEY PAIR
  associate_public_ip_address = true

  iam_instance_profile     = aws_iam_instance_profile.iam_instance_profile.name
  vpc_security_group_ids   = [aws_security_group.security_group.id]
  monitoring               = true  # Enable detailed monitoring

  tags = {
    Name = "instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y software-properties-common
              sudo add-apt-repository -y ppa:ethereum/ethereum
              sudo apt-get update
              sudo apt-get install -y ethereum

              # Install Prometheus and node_exporter
              sudo apt-get install -y prometheus
              sudo apt-get install -y prometheus-node-exporter

              # Configure Prometheus
              sudo cat <<EOL > /etc/prometheus/prometheus.yml
                global:
                  scrape_interval:     15s
                  evaluation_interval: 15s

                scrape_configs:
                  - job_name: 'geth'
                    static_configs:
                      - targets: ['localhost:8545'] # Assuming Geth is running on the same instance

                  - job_name: 'node_exporter'
                    static_configs:
                      - targets: ['localhost:9100'] # Assuming node_exporter is running on the same instance
              EOL

              # Start Prometheus
              sudo systemctl enable prometheus
              sudo systemctl start prometheus

              # Start node_exporter
              sudo systemctl enable prometheus-node-exporter
              sudo systemctl start prometheus-node-exporter

              # Configure CloudWatch logging
              sudo apt-get install -y awslogs
              sudo service awslogs start
              sudo systemctl enable awslogs

              # Use the created log group name
              sudo echo "/var/log/syslog {
                missingok
                monthly
                create 0644 root root
                rotate 5
              }" | sudo tee /etc/awslogs/awslogs.conf.d/geth.conf

              sudo systemctl restart awslogs
            EOF
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "instance-log-stream"
  log_group_name = aws_cloudwatch_log_group.log_group.name
  depends_on     = [aws_instance.instance]
}
