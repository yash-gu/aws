# VPC Basic Setup

## Overview
This guide covers creating a custom VPC in AWS, launching EC2 instances inside it, and implementing public/private connectivity with proper networking.

![VPC Architecture](https://docs.aws.amazon.com/images/vpc/latest/userguide/images/vpc-subnet-diagram.png)

## Prerequisites
- AWS Account with appropriate permissions
- Understanding of CIDR notation
- AWS CLI installed (optional)

---

## Step 1: Create Custom VPC

### 1.1 Navigate to VPC Console
1. Go to **AWS Console** → **VPC**
2. Click **Create VPC**

### 1.2 VPC Configuration
| Setting | Value | Description |
|---------|-------|-------------|
| **VPC Settings** | VPC and more | Creates VPC + subnets + IGW |
| **Name tag** | `my-custom-vpc` | Identifier |
| **IPv4 CIDR** | `10.0.0.0/16` | 65,536 IP addresses |
| **IPv6 CIDR** | No IPv6 CIDR | Optional |
| **Tenancy** | Default | Shared hardware |

### 1.3 Subnet Configuration
Configure 2 Availability Zones with public and private subnets:

| Subnet | AZ | CIDR | Type |
|--------|-----|------|------|
| Public-1a | us-east-1a | 10.0.1.0/24 | Public |
| Public-1b | us-east-1b | 10.0.2.0/24 | Public |
| Private-1a | us-east-1a | 10.0.3.0/24 | Private |
| Private-1b | us-east-1b | 10.0.4.0/24 | Private |

### 1.4 NAT Gateway & Connectivity
| Setting | Value |
|---------|-------|
| **NAT Gateways** | 1 per AZ (recommended for prod) |
| **VPC Endpoints** | S3 Gateway (optional) |

### 1.5 Create VPC
Click **Create VPC** and wait for all resources to be created (takes ~2 minutes).

![VPC Creation](https://docs.aws.amazon.com/images/vpc/latest/userguide/images/create-vpc-with-resources.png)

---

## Step 2: Verify Created Resources

### 2.1 Check Created Components
Navigate to each section and verify:

```bash
# Components Created:
├── VPC: my-custom-vpc (10.0.0.0/16)
├── Internet Gateway: Attached to VPC
├── NAT Gateways: In each public subnet
├── Subnets: 4 subnets (2 public, 2 private)
└── Route Tables: Public and Private
```

### 2.2 Route Table Configuration

**Public Route Table:**
| Destination | Target | Purpose |
|-------------|--------|---------|
| 10.0.0.0/16 | local | Local VPC traffic |
| 0.0.0.0/0 | igw-xxxxx | Internet access |

**Private Route Table:**
| Destination | Target | Purpose |
|-------------|--------|---------|
| 10.0.0.0/16 | local | Local VPC traffic |
| 0.0.0.0/0 | nat-xxxxx | Internet via NAT |

---

## Step 3: Create Security Groups

### 3.1 Public Instance Security Group
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | My IP | Admin access |
| HTTP | TCP | 80 | 0.0.0.0/0 | Web traffic |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Secure traffic |

### 3.2 Private Instance Security Group
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Public SG | Access from public |
| Custom | All | All | VPC CIDR | Internal traffic |

---

## Step 4: Launch EC2 in VPC

### 4.1 Launch Public EC2 Instance
| Setting | Value |
|---------|-------|
| **Name** | `public-web-server` |
| **AMI** | Amazon Linux 2023 |
| **Instance Type** | t2.micro |
| **VPC** | my-custom-vpc |
| **Subnet** | Public-1a (10.0.1.0/24) |
| **Auto-assign IP** | Enable |
| **Security Group** | Public SG |
| **Key Pair** | Create/select existing |

### 4.2 Launch Private EC2 Instance
| Setting | Value |
|---------|-------|
| **Name** | `private-app-server` |
| **AMI** | Amazon Linux 2023 |
| **Instance Type** | t2.micro |
| **VPC** | my-custom-vpc |
| **Subnet** | Private-1a (10.0.3.0/24) |
| **Auto-assign IP** | Disable |
| **Security Group** | Private SG |
| **Key Pair** | Same key as public |

![EC2 in VPC](https://docs.aws.amazon.com/images/AWSEC2/latest/UserGuide/images/instance-details.png)

---

## Step 5: Configure Connectivity

### 5.1 Connect to Public Instance
```bash
# Using SSH
ssh -i my-key.pem ec2-user@<PUBLIC_INSTANCE_IP>

# Example
ssh -i my-key.pem ec2-user@54.123.45.67
```

### 5.2 SSH from Public to Private (Bastion/Jump Host)

#### Method 1: SSH Agent Forwarding
```bash
# On local machine, add key to agent
ssh-add -K my-key.pem

# SSH to public with agent forwarding
ssh -A ec2-user@<PUBLIC_IP>

# From public instance, SSH to private
ssh ec2-user@<PRIVATE_IP>
```

#### Method 2: Copy Key to Public Instance
```bash
# On local machine, copy key
scp -i my-key.pem my-key.pem ec2-user@<PUBLIC_IP>:/home/ec2-user/

# SSH to public
ssh -i my-key.pem ec2-user@<PUBLIC_IP>

# Set permissions and connect to private
chmod 400 my-key.pem
ssh -i my-key.pem ec2-user@<PRIVATE_IP>
```

#### Method 3: Using ProxyJump (Modern SSH)
```bash
# Single command from local machine
ssh -i my-key.pem -J ec2-user@<PUBLIC_IP> ec2-user@<PRIVATE_IP>

# Or add to ~/.ssh/config
Host public-bastion
    HostName <PUBLIC_IP>
    User ec2-user
    IdentityFile ~/.ssh/my-key.pem

Host private-server
    HostName <PRIVATE_IP>
    User ec2-user
    IdentityFile ~/.ssh/my-key.pem
    ProxyJump public-bastion

# Then simply run
ssh private-server
```

### 5.3 SSH Config File Setup
Create `~/.ssh/config`:
```
Host bastion
    HostName 54.123.45.67
    User ec2-user
    IdentityFile ~/.ssh/my-key.pem
    StrictHostKeyChecking no

Host private
    HostName 10.0.3.45
    User ec2-user
    IdentityFile ~/.ssh/my-key.pem
    ProxyJump bastion
    StrictHostKeyChecking no
```

---

## Step 6: Verify Connectivity

### 6.1 Test Internet from Public Instance
```bash
# Should work - has public IP and IGW route
ping -c 4 google.com
curl ifconfig.me  # Shows public IP
```

### 6.2 Test Internet from Private Instance
```bash
# Should work - via NAT Gateway
ping -c 4 google.com
yum update -y     # Package manager works

# Should NOT have public IP
curl ifconfig.me  # Returns NAT Gateway IP
```

### 6.3 Test Internal Communication
```bash
# From public instance
ping <PRIVATE_IP>

# From private instance
ping <PUBLIC_IP>
```

---

## Step 7: Install Web Server on Public Instance

### 7.1 Install Nginx
```bash
# Connect to public instance
ssh -i my-key.pem ec2-user@<PUBLIC_IP>

# Install and start Nginx
sudo dnf update -y
sudo dnf install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 7.2 Verify Web Access
```bash
# Get public IP
curl ifconfig.me

# Access in browser
http://<PUBLIC_IP>
```

---
