 Smart VPN EC2 Manager
![What it Does](https://or9.ca/images/CloudBridge.png)
`smart-vpn-ec2-manager` provides an intelligent way to manage the lifecycle of expensive EC2 instances. By monitoring WireGuard VPN connectivity, this Terraform solution ensures that your EC2 instance is only active when needed, thus saving on costs.

## Features

- **Dynamic EC2 Management**: Automatically power on your EC2 instance when you connect to the VPN and power it off after disconnecting.
- **WireGuard VPN Integration**: Securely access your EC2 instance using the robust WireGuard VPN protocol.
- **CloudWatch & SNS Monitoring**: Efficiently track VPN connectivity events to manage EC2 lifecycle with CloudWatch and SNS.

## File Structure

- `vpnwatch.tf`: Contains configurations for CloudWatch monitoring and SNS notifications.
- `wireguard.tf`: Provides the setup for a WireGuard VPN that can access the designated EC2 instance.
- `generic-instance.tf`: Creates a high-capacity EC2 instance optimized for specific project needs, the costs of which are significantly minimized through the dynamic management.

## Getting Started

1. **Prerequisites**: Ensure you have Terraform installed and AWS credentials set up.
2. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/smart-vpn-ec2-manager.git
   cd smart-vpn-ec2-manager
3. I used a pem key called terraform-vpn-key so you may need to refractor to change this name. 
4. To deploy within a python venv and not on host os use this repo  https://github.com/orionnelson/aws-terraform-venv
