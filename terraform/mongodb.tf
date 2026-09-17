data "aws_ami" "mongodb" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
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
              apt-get install -y gnupg curl jq unzip

              # Install AWS CLI v2
              curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
              unzip -q /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install
              rm -rf /tmp/aws /tmp/awscliv2.zip

              # Install MongoDB 7.0 from official repo
              curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
                gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
              echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/7.0 multiverse" \
                > /etc/apt/sources.list.d/mongodb-org-7.0.list
              apt-get update -y
              apt-get install -y mongodb-org

              timedatectl set-timezone ${var.schedule_timezone}

              systemctl enable mongod
              systemctl start mongod

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

              mongosh admin --eval "
                db.createUser({
                  user: '$MONGO_USER',
                  pwd: '$MONGO_PASS',
                  roles: [{ role: 'root', db: 'admin' }]
                })
              "

              # Enable auth and bind to all interfaces in mongod.conf (YAML format)
              cat >> /etc/mongod.conf <<'MONGOCFG'

security:
  authorization: enabled
MONGOCFG
              sed -i 's/^  bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf

              systemctl restart mongod

              cat > /opt/mongodb-backup.sh << 'BACKUP'
              #!/bin/bash
              set -euo pipefail

              DATE=$(date +%Y-%m-%d)
              BACKUP_DIR="/opt/mongodb-backups/$${DATE}"
              REGION="${var.aws_region}"
              BUCKET="${aws_s3_bucket.backup.id}"

              mkdir -p "$${BACKUP_DIR}"

              CREDS=$(aws secretsmanager get-secret-value \
                --region "$REGION" \
                --secret-id "${var.project_name}/mongodb-credentials" \
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

              (
                set +e
                echo "Starting restore at $(date)" >> /var/log/mongodb-restore.log

                LATEST_BACKUP=$(aws s3 ls "s3://${aws_s3_bucket.backup.id}/" --region "${var.aws_region}" 2>/dev/null \
                  | grep 'PRE' | awk '{print $2}' | tr -d '/' | sort -r | head -1)

                if [ -n "$LATEST_BACKUP" ]; then
                  echo "Restoring from backup: $LATEST_BACKUP" >> /var/log/mongodb-restore.log
                  mkdir -p /opt/mongodb-restore

                  aws s3 cp \
                    "s3://${aws_s3_bucket.backup.id}/$LATEST_BACKUP/" \
                    "/opt/mongodb-restore/$LATEST_BACKUP/" \
                    --recursive --region "${var.aws_region}" \
                    >> /var/log/mongodb-restore.log 2>&1

                  mongorestore \
                    --host localhost \
                    --authenticationDatabase admin \
                    --username "$MONGO_USER" \
                    --password "$MONGO_PASS" \
                    --drop \
                    "/opt/mongodb-restore/$LATEST_BACKUP/" \
                    >> /var/log/mongodb-restore.log 2>&1

                  rm -rf /opt/mongodb-restore
                  echo "Restore completed at $(date)" >> /var/log/mongodb-restore.log
                else
                  echo "No backups found in S3" >> /var/log/mongodb-restore.log
                fi
              ) || echo "Restore failed at $(date)" >> /var/log/mongodb-restore.log
              EOF

  depends_on = [
    aws_iam_role_policy.mongodb_s3_backup,
    aws_iam_role_policy.mongodb_secrets_manager,
    aws_iam_role_policy.mongodb_cloudwatch_logs,
    aws_iam_role_policy.mongodb_ec2_access,
  ]

  tags = {
    Name    = "${var.project_name}-mongodb"
    Purpose = "Wiz Technical Exercise"
  }
}
