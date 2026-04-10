# Basic EC2 + Web Server (Nginx)

## Overview
This guide walks you through creating an EC2 instance on AWS, installing Nginx web server, and accessing it via browser.

![EC2 Architecture](https://docs.aws.amazon.com/images/AWSEC2/latest/UserGuide/images/overview-ec2.png)

## Prerequisites
- AWS Account with appropriate permissions
- Basic knowledge of Linux commands
- SSH client installed on your local machine

---

## Step 1: Create EC2 Instance

### 1.1 Navigate to EC2 Dashboard
1. Log in to AWS Management Console
2. Navigate to **Services** → **EC2**
3. Click **Launch Instance**

### 1.2 Configure Instance
| Setting | Value |
|---------|-------|
| **Name** | `nginx-web-server` |
| **AMI** | Amazon Linux 2023 / Ubuntu Server 22.04 LTS |
| **Instance Type** | t2.micro (free tier eligible) |
| **Key Pair** | Create new or select existing |
| **VPC** | Default VPC |
| **Subnet** | Any public subnet |
| **Auto-assign public IP** | Enable |

### 1.3 Configure Security Group
Create a security group with the following inbound rules:

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| SSH | TCP | 22 | My IP | SSH Access |
| HTTP | TCP | 80 | Anywhere (0.0.0.0/0) | Web Traffic |
| HTTPS | TCP | 443 | Anywhere (0.0.0.0/0) | Secure Web |

![Security Group](https://docs.aws.amazon.com/images/vpc/latest/userguide/images/security-group-overview.png)

### 1.4 Launch Instance
Click **Launch Instance** and wait for the instance state to become **Running**.

---

## Step 2: Install Nginx

### 2.1 Connect to EC2 Instance
```bash
# Using SSH (replace with your key and public IP)
chmod 400 your-key.pem
ssh -i your-key.pem ec2-user@<PUBLIC_IP>

# For Ubuntu
ssh -i your-key.pem ubuntu@<PUBLIC_IP>
```

### 2.2 Update System Packages
```bash
# Amazon Linux 2023
sudo dnf update -y

# Ubuntu
sudo apt update && sudo apt upgrade -y
```

### 2.3 Install Nginx

#### For Amazon Linux 2023:
```bash
sudo dnf install nginx -y
```

#### For Ubuntu:
```bash
sudo apt install nginx -y
```

### 2.4 Start and Enable Nginx
```bash
# Start Nginx service
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Check Nginx status
sudo systemctl status nginx
```

![Nginx Status](https://nginx.org/nginx.png)

---

## Step 3: Configure Nginx

### 3.1 Default Configuration Location
```
/etc/nginx/nginx.conf          # Main configuration
/etc/nginx/conf.d/             # Additional configurations
/var/www/html/                 # Default web root
/usr/share/nginx/html/         # Amazon Linux web root
```

### 3.2 Verify Configuration
```bash
# Test Nginx configuration
sudo nginx -t

# Expected output:
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 3.3 Create Custom Index Page (Optional)
```bash
# Create custom index.html
sudo tee /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>My AWS EC2 Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #FF9900; }
    </style>
</head>
<body>
    <h1>Hello from AWS EC2!</h1>
    <p>Nginx is successfully running on Amazon Linux 2023</p>
    <p>Server IP: <!--#echo var="REMOTE_ADDR" --></p>
</body>
</html>
EOF

# Reload Nginx
sudo systemctl reload nginx
```

---

## Step 4: Access via Browser

### 4.1 Get Public IP/URL
```
EC2 Console → Instances → Select Instance → Details → Public IPv4 address
Example: 3.85.167.42
```

### 4.2 Access in Browser
Open your browser and navigate to:
```
http://<PUBLIC_IP>
http://3.85.167.42
```

![Nginx Welcome Page](https://nginx.org/welcome.png)

You should see the Nginx welcome page or your custom page.

---

## Troubleshooting

### Issue: Connection Refused
```bash
# Check if Nginx is running
sudo systemctl status nginx

# Check security group rules
# Ensure port 80 is open to 0.0.0.0/0

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Issue: Permission Denied (SSH)
```bash
# Fix key permissions
chmod 400 your-key.pem

# Check security group allows port 22 from your IP
```

### Issue: 403 Forbidden
```bash
# Check file permissions
sudo chown -R nginx:nginx /usr/share/nginx/html
sudo chmod -R 755 /usr/share/nginx/html
```

---

## Verification Checklist
- [ ] EC2 instance is running (green icon)
- [ ] Security group allows HTTP (port 80)
- [ ] Nginx service is active (`systemctl status nginx`)
- [ ] Can access via browser using public IP
- [ ] Default Nginx page loads successfully

---

## Cleanup (Optional)
To avoid charges, terminate the instance when done:
```bash
# In AWS Console: EC2 → Instances → Select → Actions → Terminate
# OR via CLI:
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│              User Browser               │
└──────────────┬──────────────────────────┘
               │ HTTP/HTTPS
               ▼
┌─────────────────────────────────────────┐
│         Internet Gateway                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│     VPC (Default or Custom)             │
│  ┌─────────────────────────────────┐    │
│  │    Public Subnet                │    │
│  │  ┌─────────────────────────┐    │    │
│  │  │    EC2 Instance         │    │    │
│  │  │  ┌─────────────────┐  │    │    │
│  │  │  │   Nginx Server  │  │    │    │
│  │  │  │   Port: 80, 443 │  │    │    │
│  │  │  └─────────────────┘  │    │    │
│  │  │  Public IP: X.X.X.X   │    │    │
│  │  └─────────────────────────┘    │    │
│  │         ↑ Security Group          │    │
│  │    (SSH:22, HTTP:80, HTTPS:443)  │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

---

## Next Steps
- Configure SSL/HTTPS with Let's Encrypt
- Set up a custom domain using Route 53
- Create an AMI from this instance for scaling
- Set up Auto Scaling and Load Balancer

---

**References:**
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Nginx Documentation](https://nginx.org/en/docs/)
