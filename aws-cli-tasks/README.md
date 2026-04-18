# AWS CLI Tasks

Install AWS CLI and create full infrastructure: VPC, subnets, IGW, NAT Gateway, security groups, EC2 with Nginx, and ALB.

## 1. Install AWS CLI

```bash
# macOS
brew install awscli
# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configure
aws configure
aws sts get-caller-identity
```

## 2. Create VPC and Subnets

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cli-vpc}]' --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support

# Public subnets
PUBLIC_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cli-public-1a}]' --query 'Subnet.SubnetId' --output text)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cli-public-1b}]' --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2 --map-public-ip-on-launch

# Private subnets
PRIVATE_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cli-private-1a}]' --query 'Subnet.SubnetId' --output text)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cli-private-1b}]' --query 'Subnet.SubnetId' --output text)
```

## 3. Create IGW and NAT Gateway

```bash
# Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=cli-igw}]' --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_1 --allocation-id $EIP_ALLOC_ID --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=cli-nat}]' --query 'NatGateway.NatGatewayId' --output text)
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID
```

## 4. Create Route Tables

```bash
# Public route table
PUBLIC_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cli-public-rt}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUBLIC_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUBLIC_RT_ID --subnet-id $PUBLIC_SUBNET_1
aws ec2 associate-route-table --route-table-id $PUBLIC_RT_ID --subnet-id $PUBLIC_SUBNET_2

# Private route table
PRIVATE_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cli-private-rt}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIVATE_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID
aws ec2 associate-route-table --route-table-id $PRIVATE_RT_ID --subnet-id $PRIVATE_SUBNET_1
aws ec2 associate-route-table --route-table-id $PRIVATE_RT_ID --subnet-id $PRIVATE_SUBNET_2
```

## 5. Create Security Groups

```bash
# ALB Security Group
ALB_SG_ID=$(aws ec2 create-security-group --group-name cli-alb-sg --description "ALB Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

# EC2 Security Group
EC2_SG_ID=$(aws ec2 create-security-group --group-name cli-ec2-sg --description "EC2 Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
```

## 6. Launch EC2 and ALB

```bash
# Key pair
aws ec2 create-key-pair --key-name cli-key --query 'KeyMaterial' --output text > cli-key.pem
chmod 400 cli-key.pem

# User data
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
echo '<h1>Hello from AWS CLI!</h1>' > /usr/share/nginx/html/index.html
EOF

# Launch EC2
AMI_ID=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-*-x86_64' 'Name=state,Values=available' --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --key-name cli-key --security-group-ids $EC2_SG_ID --subnet-id $PUBLIC_SUBNET_1 --associate-public-ip-address --user-data file://user-data.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cli-web-server}]' --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Create ALB
TG_ARN=$(aws elbv2 create-target-group --name cli-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$INSTANCE_ID

ALB_ARN=$(aws elbv2 create-load-balancer --name cli-alb --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --security-groups $ALB_SG_ID --scheme internet-facing --type application --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)
echo "http://$ALB_DNS"
```

## Cleanup

```bash
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-target-group --target-group-arn $TG_ARN
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws ec2 delete-security-group --group-id $EC2_SG_ID
aws ec2 delete-security-group --group-id $ALB_SG_ID
aws ec2 release-address --allocation-id $EIP_ALLOC_ID
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID
sleep 60
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2
aws ec2 delete-vpc --vpc-id $VPC_ID
``` 'ResourceType=natgateway,Tags=[{Key=Name,Value=cli-nat-1a}]' \
    --query 'NatGateway.NatGatewayId' --output text)

echo "NAT Gateway ID: $NAT_GW_ID"

# Wait for NAT Gateway to be available
echo "Waiting for NAT Gateway to be available..."
aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $NAT_GW_ID

echo "NAT Gateway is available!"
```

---

## Step 6: Create Route Tables using CLI

### 6.1 Create Public Route Table
```bash
# Create route table
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cli-public-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

echo "Public Route Table ID: $PUBLIC_RT_ID"

# Add route to Internet Gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Associate with public subnets
aws ec2 associate-route-table \
    --route-table-id $PUBLIC_RT_ID \
    --subnet-id $PUBLIC_SUBNET_1

aws ec2 associate-route-table \
    --route-table-id $PUBLIC_RT_ID \
    --subnet-id $PUBLIC_SUBNET_2
```

### 6.2 Create Private Route Table
```bash
# Create private route table
PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cli-private-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

echo "Private Route Table ID: $PRIVATE_RT_ID"

# Add route to NAT Gateway
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $NAT_GW_ID

# Associate with private subnets
aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RT_ID \
    --subnet-id $PRIVATE_SUBNET_1

aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RT_ID \
    --subnet-id $PRIVATE_SUBNET_2
```

---

## Step 7: Create Security Groups using CLI

### 7.1 Create Security Group for ALB
```bash
ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name cli-alb-sg \
    --description "Security group for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=cli-alb-sg}]' \
    --query 'GroupId' --output text)

echo "ALB Security Group ID: $ALB_SG_ID"

# Allow inbound HTTP/HTTPS
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp --port 443 \
    --cidr 0.0.0.0/0
```

### 7.2 Create Security Group for EC2 Instances
```bash
EC2_SG_ID=$(aws ec2 create-security-group \
    --group-name cli-ec2-sg \
    --description "Security group for EC2 instances" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=cli-ec2-sg}]' \
    --query 'GroupId' --output text)

echo "EC2 Security Group ID: $EC2_SG_ID"

# Allow SSH from anywhere (restrict in production!)
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp --port 22 \
    --cidr 0.0.0.0/0

# Allow HTTP from ALB security group
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp --port 80 \
    --source-group $ALB_SG_ID
```

---

## Step 8: Create Key Pair using CLI
```bash
# Create key pair
aws ec2 create-key-pair \
    --key-name cli-key \
    --query 'KeyMaterial' \
    --output text > cli-key.pem

# Set permissions
chmod 400 cli-key.pem

echo "Key pair created: cli-key.pem"
```

---

## Step 9: Launch EC2 Instance with User Data using CLI

### 9.1 Create User Data Script
```bash
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# Create custom index page
cat > /usr/share/nginx/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>AWS CLI Deployed Server</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .info-box {
            background: rgba(255,255,255,0.2);
            padding: 20px;
            border-radius: 10px;
            margin: 20px auto;
            max-width: 600px;
        }
    </style>
</head>
<body>
    <h1>Hello from AWS CLI!</h1>
    <div class="info-box">
        <h2>Server Information</h2>
        <p>This server was deployed entirely using AWS CLI</p>
        <p><strong>Instance ID:</strong> $(ec2-metadata -i | cut -d' ' -f2)</p>
        <p><strong>Availability Zone:</strong> $(ec2-metadata -z | cut -d' ' -f2)</p>
        <p><strong>Private IP:</strong> $(ec2-metadata -o | cut -d' ' -f2)</p>
    </div>
</body>
</html>
HTMLEOF

systemctl reload nginx
echo "Nginx installation completed at $(date)" >> /var/log/user-data.log
EOF
```

### 9.2 Get Latest Amazon Linux 2023 AMI
```bash
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters 'Name=name,Values=al2023-ami-*-x86_64' 'Name=state,Values=available' \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "AMI ID: $AMI_ID"
```

### 9.3 Launch EC2 Instance
```bash
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name cli-key \
    --security-group-ids $EC2_SG_ID \
    --subnet-id $PUBLIC_SUBNET_1 \
    --associate-public-ip-address \
    --user-data file://user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cli-web-server}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance ID: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance is running!"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Public IP: $PUBLIC_IP"
```

---

## Step 10: Create Application Load Balancer using CLI

### 10.1 Create Target Group
```bash
# Get VPC default subnet IDs for ALB
TG_ARN=$(aws elbv2 create-target-group \
    --name cli-target-group \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Target Group ARN: $TG_ARN"
```

### 10.2 Register Target
```bash
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=$INSTANCE_ID

echo "Target registered!"
```

### 10.3 Create Load Balancer
```bash
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name cli-alb \
    --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value=cli-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "ALB ARN: $ALB_ARN"

# Wait for ALB to be active
echo "Waiting for ALB to be active..."
aws elbv2 wait load-balancer-available \
    --load-balancer-arns $ALB_ARN
echo "ALB is active!"
```

### 10.4 Create Listener
```bash
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "Listener ARN: $LISTENER_ARN"
```

### 10.5 Get ALB DNS Name
```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "ALB DNS Name: $ALB_DNS"
echo ""
echo "========================================="
echo "Access your application at:"
echo "http://$ALB_DNS"
echo "========================================="
```

---

## Step 11: Complete Script (All-in-One)

### Full Deployment Script
```bash
#!/bin/bash
set -e

echo "=== AWS CLI Infrastructure Deployment ==="

# Variables
REGION="us-east-1"
export AWS_DEFAULT_REGION=$REGION

# Step 1: Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cli-vpc}]' \
    --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
echo "VPC created: $VPC_ID"

# Step 2: Create Subnets
echo "Creating Subnets..."
PUBLIC_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cli-public-1a}]' --query 'Subnet.SubnetId' --output text)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cli-public-1b}]' --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2 --map-public-ip-on-launch
echo "Subnets created"

# Step 3: Create IGW
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=cli-igw}]' --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
echo "IGW created: $IGW_ID"

# Step 4: Create NAT Gateway
echo "Creating NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_1 --allocation-id $EIP_ALLOC_ID --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=cli-nat}]' --query 'NatGateway.NatGatewayId' --output text)
echo "Waiting for NAT Gateway..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID
echo "NAT Gateway available"

# Step 5: Create Route Tables
echo "Creating Route Tables..."
PUBLIC_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cli-public-rt}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUBLIC_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUBLIC_RT_ID --subnet-id $PUBLIC_SUBNET_1
aws ec2 associate-route-table --route-table-id $PUBLIC_RT_ID --subnet-id $PUBLIC_SUBNET_2

PRIVATE_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cli-private-rt}]' --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIVATE_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID
echo "Route tables created"

# Step 6: Create Security Groups
echo "Creating Security Groups..."
ALB_SG_ID=$(aws ec2 create-security-group --group-name cli-alb-sg --description "ALB Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

EC2_SG_ID=$(aws ec2 create-security-group --group-name cli-ec2-sg --description "EC2 Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
echo "Security groups created"

# Step 7: Create Key Pair
echo "Creating Key Pair..."
aws ec2 create-key-pair --key-name cli-key --query 'KeyMaterial' --output text > cli-key.pem
chmod 400 cli-key.pem
echo "Key pair created: cli-key.pem"

# Step 8: Launch EC2
echo "Launching EC2 Instance..."
AMI_ID=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-*-x86_64' 'Name=state,Values=available' --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

cat > user-data.sh << 'EOFSCRIPT'
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
echo '<h1>Hello from AWS CLI!</h1>' > /usr/share/nginx/html/index.html
EOFSCRIPT

INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --key-name cli-key --security-group-ids $EC2_SG_ID --subnet-id $PUBLIC_SUBNET_1 --associate-public-ip-address --user-data file://user-data.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cli-web-server}]' --query 'Instances[0].InstanceId' --output text)
echo "Waiting for instance..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance running: $INSTANCE_ID"

# Step 9: Create ALB
echo "Creating Application Load Balancer..."
TG_ARN=$(aws elbv2 create-target-group --name cli-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$INSTANCE_ID

ALB_ARN=$(aws elbv2 create-load-balancer --name cli-alb --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --security-groups $ALB_SG_ID --scheme internet-facing --type application --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "Waiting for ALB..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo "VPC ID: $VPC_ID"
echo "ALB DNS: http://$ALB_DNS"
echo "Instance ID: $INSTANCE_ID"
echo "SSH Command: ssh -i cli-key.pem ec2-user@$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
echo "==========================="
```

---



