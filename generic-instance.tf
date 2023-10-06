provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "debian" {
  most_recent = true
  filter {
    name   = "name"
    values = ["debian-*"]
  }
  owners = ["379101102735"] # Debian official AMI owner ID
}

resource "aws_security_group" "generic_security_group" {
  name        = "generic_security_group"
  description = "Allow access from VPN only on vpc"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: Adjust this to limit the IP addresses that can SSH
  }
 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "http"
    cidr_blocks = ["${aws_instance.wireguard_server.public_ip}/32"]  # TODO: Adjust this to limit the IP addresses that can access port 80
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.debian.id
  instance_type          = "t3.xlarge"
  vpc_security_group_ids = [aws_security_group.generic_security_group.id]
  #key_name = "terraform-vpn-key"

  tags = {
    Name = "generic-instance"
  }
}
