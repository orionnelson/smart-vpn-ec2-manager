
resource "null_resource" "wg_keys" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "wg genkey | tee client_privatekey | wg pubkey > client_publickey && wg genkey | tee server_privatekey | wg pubkey > server_publickey"
    interpreter = ["/bin/bash", "-c"]
  }
}

data "local_file" "server_privatekey" {
  filename = "server_privatekey"
  depends_on = [null_resource.wg_keys]
}

data "local_file" "client_publickey" {
  filename = "client_publickey"
  depends_on = [null_resource.wg_keys]
}

data "local_file" "client_privatekey" {
  filename = "client_privatekey"
  depends_on = [null_resource.wg_keys]
}

data "local_file" "server_publickey" {
  filename = "server_publickey"
  depends_on = [null_resource.wg_keys]
}


resource "null_resource" "wg_client_config" {

  depends_on = [
    aws_instance.wireguard_server
  ]

provisioner "local-exec" {
  command = "echo '[Interface]' > client_config.conf; echo 'PrivateKey = ${data.local_file.client_privatekey.content}' >> client_config.conf;echo 'DNS = 8.8.8.8' >> client_config.conf ; echo 'Address = 10.0.0.2/32' >> client_config.conf; echo '' >> client_config.conf; echo '[Peer]' >> client_config.conf; echo 'PublicKey = ${data.local_file.server_publickey.content}' >> client_config.conf; echo 'AllowedIPs = 0.0.0.0/0, ::/0' >> client_config.conf; echo 'Endpoint = ${aws_instance.wireguard_server.public_ip}:51820' >> client_config.conf; echo '@echo off' > connect_vpn.bat; echo 'cd %PROGRAMFILES%\\WireGuard\\' >> connect_vpn.bat; echo 'start /b wg-quick.exe up ^%~dp0client_config.conf' >> connect_vpn.bat; echo '#!/bin/bash' > connect_vpn.sh; echo 'wg-quick up ./client_config.conf' >> connect_vpn.sh; chmod +x connect_vpn.sh"
  interpreter = ["/bin/bash", "-c"]
}
}


  /**provisioner "local-exec" {
    command = <<EOF
      echo "[Interface]" > client_config.conf
      echo "PrivateKey = $(cat client_privatekey)" >> client_config.conf
      echo "Address = 10.0.0.2/32" >> client_config.conf
      echo "" >> client_config.conf
      echo "[Peer]" >> client_config.conf
      echo "PublicKey = $(cat server_publickey)" >> client_config.conf
      echo "AllowedIPs = 0.0.0.0/0, ::/0" >> client_config.conf
      echo "Endpoint = ${aws_instance.wireguard_server.public_ip}:51820" >> client_config.conf

      echo "@echo off" > connect_vpn.bat
      echo "cd %PROGRAMFILES%\\WireGuard\\" >> connect_vpn.bat
      echo "start /b wg-quick.exe up ^%~dp0client_config.conf" >> connect_vpn.bat

      echo "#!/bin/bash" > connect_vpn.sh
      echo "wg-quick up ./client_config.conf" >> connect_vpn.sh
      chmod +x connect_vpn.sh
    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}
**/


resource "aws_instance" "wireguard_server" {
  ami           = "ami-01e5ff16fd6e8c542" 
  instance_type = "t3.nano"
  key_name      = "terraform-vpn-key"

  vpc_security_group_ids = [aws_security_group.wg_security_group.id]

  tags = {
    Name = "WireguardVPN"
  }

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = file("terraform-vpn-key.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y wireguard",
      "sudo sysctl -w net.ipv4.ip_forward=1",
      "sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o ens5 -j MASQUERADE",
      "echo '[Interface]' | sudo tee /etc/wireguard/wg0.conf",
      "echo -n 'PrivateKey = ' | sudo tee -a /etc/wireguard/wg0.conf",
      "echo '${data.local_file.server_privatekey.content}' | sudo tee -a /etc/wireguard/wg0.conf",#"echo '${filebase64("server_privatekey")}' | base64 --decode | sudo tee -a /etc/wireguard/wg0.conf",
      "echo 'Address = 10.0.0.1/24' | sudo tee -a /etc/wireguard/wg0.conf",
      "echo 'ListenPort = 51820' | sudo tee -a /etc/wireguard/wg0.conf",
      "echo '[Peer]' | sudo tee -a /etc/wireguard/wg0.conf",
      "echo -n 'PublicKey = ' | sudo tee -a /etc/wireguard/wg0.conf",
      "echo '${data.local_file.client_publickey.content}' | sudo tee -a /etc/wireguard/wg0.conf",
      "echo 'AllowedIPs = 10.0.0.2/32' | sudo tee -a /etc/wireguard/wg0.conf",
      "sudo systemctl enable wg-quick@wg0",
      "sudo systemctl start wg-quick@wg0",
    ]
  }

  depends_on = [
    null_resource.wg_keys
  ]
}



resource "aws_security_group" "wg_security_group" {
  name        = "wg_security_group"
  description = "Wireguard VPN security group"

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "wireguard_public_ip" {
  value = aws_instance.wireguard_server.public_ip
  description = "Private IP of the WireGuard VPN server."
}