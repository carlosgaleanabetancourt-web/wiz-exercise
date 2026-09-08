resource "aws_security_group" "mongodb" {
  name = "${var.project_name}-mongodb"
  description = "MongoDB security group"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB from VPC"
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-mongodb"
  }
}