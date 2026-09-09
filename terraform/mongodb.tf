data "aws_ami" "mongodb" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "exercise" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "mongodb" {
  ami           = data.aws_ami.mongodb.id
  instance_type = "t3.micro"

  subnet_id = module.vpc.public_subnets[0]

  vpc_security_group_ids = [
    aws_security_group.mongodb.id
  ]

  key_name = aws_key_pair.exercise.key_name

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.mongodb.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail

              apt-get update -y
              apt-get install -y mongodb awscli jq

              systemctl enable mongodb
              systemctl start mongodb

              sleep 5

              REGION="${var.aws_region}"
              SECRET_ID="${aws_secretsmanager_secret.mongodb_credentials.name}"

              CREDS=$(aws secretsmanager get-secret-value \
                --region "$REGION" \
                --secret-id "$SECRET_ID" \
                --query SecretString \
                --output text)

              MONGO_USER=$(echo "$CREDS" | jq -r '.username')
              MONGO_PASS=$(echo "$CREDS" | jq -r '.password')

              mongo admin --eval "
                db.createUser({
                  user: '$MONGO_USER',
                  pwd: '$MONGO_PASS',
                  roles: [{ role: 'root', db: 'admin' }]
                })
              "

              sed -i 's/^#auth = true/auth = true/' /etc/mongodb.conf
              grep -q '^auth' /etc/mongodb.conf || echo 'auth = true' >> /etc/mongodb.conf

              sed -i 's/^bind_ip.*/bind_ip = 0.0.0.0/' /etc/mongodb.conf

              systemctl restart mongodb

              cat > /opt/mongodb-backup.sh << 'BACKUP'
              #!/bin/bash
              set -euo pipefail

              DATE=$(date +%Y-%m-%d)
              BACKUP_DIR="/opt/mongodb-backups/$${DATE}"
              REGION="${var.aws_region}"
              PROJECT="${var.project_name}"

              BUCKET=$(aws s3api list-buckets \
                --query "Buckets[?starts_with(Name, '$${PROJECT}-backup-') && !contains(Name, 'logs')].Name | [0]" \
                --output text)

              if [ "$BUCKET" = "None" ] || [ -z "$BUCKET" ]; then
                echo "ERROR: backup bucket not found" >&2
                exit 1
              fi

              mkdir -p "$${BACKUP_DIR}"

              CREDS=$(aws secretsmanager get-secret-value \
                --region "$REGION" \
                --secret-id "$${PROJECT}/mongodb-credentials" \
                --query SecretString \
                --output text)

              MONGO_USER=$(echo "$CREDS" | jq -r '.username')
              MONGO_PASS=$(echo "$CREDS" | jq -r '.password')

              mongodump \
                --host localhost \
                --authenticationDatabase admin \
                --username "$MONGO_USER" \
                --password "$MONGO_PASS" \
                --out "$${BACKUP_DIR}"

              aws s3 cp \
                "$${BACKUP_DIR}" \
                "s3://$${BUCKET}/$${DATE}/" \
                --recursive

              find /opt/mongodb-backups -type d -mtime +7 -exec rm -rf {} +
              BACKUP

              chmod +x /opt/mongodb-backup.sh

              echo "0 21 * * * root /opt/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1" > /etc/cron.d/mongodb-backup
              chmod 644 /etc/cron.d/mongodb-backup
              EOF

  tags = {
    Name    = "${var.project_name}-mongodb"
    Purpose = "Wiz Technical Exercise"
  }
}
