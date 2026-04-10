# VPC Peering (Advanced Networking)

## Overview
This guide covers setting up VPC peering between two VPCs (can be in different accounts), configuring non-overlapping CIDRs, and establishing SSH connectivity between private instances.

![VPC Peering Architecture](https://docs.aws.amazon.com/images/vpc/latest/peering/images/peering-intro-diagram.png)

## Prerequisites
- Two AWS accounts (or two VPCs in same account)
- IAM permissions to create VPC peering connections
- Understanding of route tables and security groups

---

## Step 1: Create Two VPCs with Non-Overlapping CIDR

### 1.1 VPC A - First Account (Requester)
| Setting | Value |
|---------|-------|
| **VPC Name** | `vpc-a-prod` |
| **IPv4 CIDR** | `10.0.0.0/16` |
| **Tenancy** | Default |

```bash
# Create VPC A
VPC_A_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-a-prod}]' \
    --query 'Vpc.VpcId' --output text)

echo "VPC A ID: $VPC_A_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id $VPC_A_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_A_ID --enable-dns-support
```

### 1.2 VPC B - Second Account (Accepter)
| Setting | Value |
|---------|-------|
| **VPC Name** | `vpc-b-dev` |
| **IPv4 CIDR** | `10.1.0.0/16` |
| **Tenancy** | Default |

```bash
# Create VPC B (in different account)
VPC_B_ID=$(aws ec2 create-vpc \
    --cidr-block 10.1.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-b-dev}]' \
    --query 'Vpc.VpcId' --output text)

echo "VPC B ID: $VPC_B_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id $VPC_B_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_B_ID --enable-dns-support
```

### 1.3 CIDR Comparison
| VPC | CIDR | IP Range | Use |
|-----|------|----------|-----|
| VPC A | 10.0.0.0/16 | 10.0.0.0 - 10.0.255.255 | Production |
| VPC B | 10.1.0.0/16 | 10.1.0.0 - 10.1.255.255 | Development |

**Important:** CIDRs must NOT overlap for peering to work!

---

## Step 2: Create Subnets and Infrastructure

### 2.1 VPC A Subnets
```bash
# Create public subnet in VPC A
PUBLIC_SUBNET_A=$(aws ec2 create-subnet \
    --vpc-id $VPC_A_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-a-public-1a}]' \
    --query 'Subnet.SubnetId' --output text)

# Create private subnet in VPC A
PRIVATE_SUBNET_A=$(aws ec2 create-subnet \
    --vpc-id $VPC_A_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-a-private-1a}]' \
    --query 'Subnet.SubnetId' --output text)

echo "Public Subnet A: $PUBLIC_SUBNET_A"
echo "Private Subnet A: $PRIVATE_SUBNET_A"
```

### 2.2 VPC B Subnets
```bash
# Create public subnet in VPC B
PUBLIC_SUBNET_B=$(aws ec2 create-subnet \
    --vpc-id $VPC_B_ID \
    --cidr-block 10.1.1.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-b-public-1b}]' \
    --query 'Subnet.SubnetId' --output text)

# Create private subnet 1 in VPC B
PRIVATE_SUBNET_B1=$(aws ec2 create-subnet \
    --vpc-id $VPC_B_ID \
    --cidr-block 10.1.2.0/24 \
    --availability-zone us-east-1b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-b-private-1}]' \
    --query 'Subnet.SubnetId' --output text)

# Create private subnet 2 in VPC B
PRIVATE_SUBNET_B2=$(aws ec2 create-subnet \
    --vpc-id $VPC_B_ID \
    --cidr-block 10.1.3.0/24 \
    --availability-zone us-east-1c \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-b-private-2}]' \
    --query 'Subnet.SubnetId' --output text)

echo "Public Subnet B: $PUBLIC_SUBNET_B"
echo "Private Subnet B1: $PRIVATE_SUBNET_B1"
echo "Private Subnet B2: $PRIVATE_SUBNET_B2"
```

### 2.3 Create Internet Gateways
```bash
# IGW for VPC A
IGW_A=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-vpc-a}]' \
    --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_A --vpc-id $VPC_A_ID

# IGW for VPC B
IGW_B=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-vpc-b}]' \
    --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_B --vpc-id $VPC_B_ID
```

---

## Step 3: Create VPC Peering Connection

### 3.1 Request Peering (From VPC A Account)
```bash
# Request peering connection to VPC B
PEERING_ID=$(aws ec2 create-vpc-peering-connection \
    --vpc-id $VPC_A_ID \
    --peer-vpc-id $VPC_B_ID \
    --peer-owner-id <VPC_B_ACCOUNT_ID> \
    --peer-region us-east-1 \
    --tag-specifications 'ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=vpc-a-to-vpc-b}]' \
    --query 'VpcPeeringConnection.VpcPeeringConnectionId' --output text)

echo "Peering Connection ID: $PEERING_ID"
```

### 3.2 Accept Peering (From VPC B Account)
```bash
# Accept the peering request
aws ec2 accept-vpc-peering-connection \
    --vpc-peering-connection-id $PEERING_ID
```

### 3.3 Verify Peering Connection
```bash
aws ec2 describe-vpc-peering-connections \
    --vpc-peering-connection-ids $PEERING_ID \
    --query 'VpcPeeringConnections[0].{ID:VpcPeeringConnectionId,Status:Status.Code,VPC1:RequesterVpcInfo.VpcId,VPC2:AccepterVpcInfo.VpcId}'

# Status should be "active"
```

![VPC Peering](https://docs.aws.amazon.com/images/vpc/latest/peering/images/one-vpc-peered.png)

---

## Step 4: Update Route Tables

### 4.1 VPC A Route Tables
```bash
# Create public route table for VPC A
RT_PUBLIC_A=$(aws ec2 create-route-table \
    --vpc-id $VPC_A_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-a-public-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

# Add routes
aws ec2 create-route --route-table-id $RT_PUBLIC_A --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_A
aws ec2 create-route --route-table-id $RT_PUBLIC_A --destination-cidr-block 10.1.0.0/16 --vpc-peering-connection-id $PEERING_ID

# Create private route table for VPC A
RT_PRIVATE_A=$(aws ec2 create-route-table \
    --vpc-id $VPC_A_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-a-private-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

# Add peering route to private RT
aws ec2 create-route --route-table-id $RT_PRIVATE_A --destination-cidr-block 10.1.0.0/16 --vpc-peering-connection-id $PEERING_ID

# Associate with subnets
aws ec2 associate-route-table --route-table-id $RT_PUBLIC_A --subnet-id $PUBLIC_SUBNET_A
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_A --subnet-id $PRIVATE_SUBNET_A
```

### 4.2 VPC B Route Tables
```bash
# Create public route table for VPC B
RT_PUBLIC_B=$(aws ec2 create-route-table \
    --vpc-id $VPC_B_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-b-public-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

# Add routes
aws ec2 create-route --route-table-id $RT_PUBLIC_B --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_B
aws ec2 create-route --route-table-id $RT_PUBLIC_B --destination-cidr-block 10.0.0.0/16 --vpc-peering-connection-id $PEERING_ID

# Create private route table for VPC B
RT_PRIVATE_B=$(aws ec2 create-route-table \
    --vpc-id $VPC_B_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=vpc-b-private-rt}]' \
    --query 'RouteTable.RouteTableId' --output text)

# Add peering route to private RT
aws ec2 create-route --route-table-id $RT_PRIVATE_B --destination-cidr-block 10.0.0.0/16 --vpc-peering-connection-id $PEERING_ID

# Associate with subnets
aws ec2 associate-route-table --route-table-id $RT_PUBLIC_B --subnet-id $PUBLIC_SUBNET_B
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_B --subnet-id $PRIVATE_SUBNET_B1
aws ec2 associate-route-table --route-table-id $RT_PRIVATE_B --subnet-id $PRIVATE_SUBNET_B2
```

### 4.3 Route Summary
| Route Table | Destination | Target |
|-------------|-------------|--------|
| VPC-A Public | 0.0.0.0/0 | IGW-A |
| VPC-A Public | 10.1.0.0/16 | Peering |
| VPC-A Private | 10.1.0.0/16 | Peering |
| VPC-B Public | 0.0.0.0/0 | IGW-B |
| VPC-B Public | 10.0.0.0/16 | Peering |
| VPC-B Private | 10.0.0.0/16 | Peering |

---

## Step 5: Create Security Groups

### 5.1 VPC A Security Groups
```bash
# Public bastion security group
SG_PUBLIC_A=$(aws ec2 create-security-group \
    --group-name vpc-a-public-sg \
    --description "Public bastion SG for VPC A" \
    --vpc-id $VPC_A_ID \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SG_PUBLIC_A \
    --protocol tcp --port 22 --cidr 0.0.0.0/0

# Private security group
SG_PRIVATE_A=$(aws ec2 create-security-group \
    --group-name vpc-a-private-sg \
    --description "Private instances SG for VPC A" \
    --vpc-id $VPC_A_ID \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SG_PRIVATE_A \
    --protocol tcp --port 22 --source-group $SG_PUBLIC_A
```

### 5.2 VPC B Security Groups
```bash
# Public security group
SG_PUBLIC_B=$(aws ec2 create-security-group \
    --group-name vpc-b-public-sg \
    --description "Public instances SG for VPC B" \
    --vpc-id $VPC_B_ID \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SG_PUBLIC_B \
    --protocol tcp --port 22 --cidr 0.0.0.0/0

# Private security groups for Private VM 1 and 2
SG_PRIVATE_B1=$(aws ec2 create-security-group \
    --group-name vpc-b-private-sg-1 \
    --description "Private VM 1 SG for VPC B" \
    --vpc-id $VPC_B_ID \
    --query 'GroupId' --output text)

SG_PRIVATE_B2=$(aws ec2 create-security-group \
    --group-name vpc-b-private-sg-2 \
    --description "Private VM 2 SG for VPC B" \
    --vpc-id $VPC_B_ID \
    --query 'GroupId' --output text)

# Allow SSH from Public VM B to Private VMs
aws ec2 authorize-security-group-ingress \
    --group-id $SG_PRIVATE_B1 \
    --protocol tcp --port 22 --source-group $SG_PUBLIC_B

aws ec2 authorize-security-group-ingress \
    --group-id $SG_PRIVATE_B2 \
    --protocol tcp --port 22 --source-group $SG_PRIVATE_B1

# Allow inter-private communication
aws ec2 authorize-security-group-ingress \
    --group-id $SG_PRIVATE_B2 \
    --protocol tcp --port 22 --source-group $SG_PRIVATE_B1
```

---

## Step 6: Launch EC2 Instances

### 6.1 VPC A - Public VM (Bastion)
```bash
# Get latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters 'Name=name,Values=al2023-ami-*-x86_64' 'Name=state,Values=available' \
    --query 'Images[0].ImageId' --output text)

# Create key pair
aws ec2 create-key-pair --key-name vpc-a-key --query 'KeyMaterial' --output text > vpc-a-key.pem
chmod 400 vpc-a-key.pem

# Launch public instance in VPC A
VM_PUBLIC_A=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name vpc-a-key \
    --security-group-ids $SG_PUBLIC_A \
    --subnet-id $PUBLIC_SUBNET_A \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vpc-a-bastion}]' \
    --query 'Instances[0].InstanceId' --output text)

PUBLIC_IP_A=$(aws ec2 describe-instances \
    --instance-ids $VM_PUBLIC_A \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "VPC A Public VM IP: $PUBLIC_IP_A"
```

### 6.2 VPC B - Public VM
```bash
# Create key pair in VPC B account
aws ec2 create-key-pair --key-name vpc-b-key --query 'KeyMaterial' --output text > vpc-b-key.pem
chmod 400 vpc-b-key.pem

# Launch public instance
VM_PUBLIC_B=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name vpc-b-key \
    --security-group-ids $SG_PUBLIC_B \
    --subnet-id $PUBLIC_SUBNET_B \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vpc-b-public}]' \
    --query 'Instances[0].InstanceId' --output text)

PUBLIC_IP_B=$(aws ec2 describe-instances \
    --instance-ids $VM_PUBLIC_B \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "VPC B Public VM IP: $PUBLIC_IP_B"
```

### 6.3 VPC B - Private VM 1
```bash
VM_PRIVATE_B1=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name vpc-b-key \
    --security-group-ids $SG_PRIVATE_B1 \
    --subnet-id $PRIVATE_SUBNET_B1 \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vpc-b-private-1}]' \
    --query 'Instances[0].InstanceId' --output text)

PRIVATE_IP_B1=$(aws ec2 describe-instances \
    --instance-ids $VM_PRIVATE_B1 \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

echo "VPC B Private VM 1 IP: $PRIVATE_IP_B1"
```

### 6.4 VPC B - Private VM 2
```bash
VM_PRIVATE_B2=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name vpc-b-key \
    --security-group-ids $SG_PRIVATE_B2 \
    --subnet-id $PRIVATE_SUBNET_B2 \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vpc-b-private-2}]' \
    --query 'Instances[0].InstanceId' --output text)

PRIVATE_IP_B2=$(aws ec2 describe-instances \
    --instance-ids $VM_PRIVATE_B2 \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

echo "VPC B Private VM 2 IP: $PRIVATE_IP_B2"
```

---

## Step 7: SSH Connectivity Testing

### 7.1 SSH to Public VM B
```bash
# From your local machine
ssh -i vpc-b-key.pem ec2-user@$PUBLIC_IP_B
```

### 7.2 SSH from Public VM B to Private VM 1
```bash
# While connected to Public VM B
# Copy the private key
cat > /tmp/vpc-b-key.pem << 'EOF'
# Paste contents of vpc-b-key.pem here
EOF
chmod 400 /tmp/vpc-b-key.pem

# SSH to Private VM 1
ssh -i /tmp/vpc-b-key.pem ec2-user@$PRIVATE_IP_B1
```

### 7.3 SSH from Private VM 1 to Private VM 2
```bash
# While connected to Private VM 1
# Copy the key again if needed
ssh -i /tmp/vpc-b-key.pem ec2-user@$PRIVATE_IP_B2
```

### 7.4 One-Command Multi-Hop SSH
```bash
# From local machine to Private VM 2 via Public VM B and Private VM 1
ssh -i vpc-b-key.pem -J ec2-user@$PUBLIC_IP_B,ec2-user@$PRIVATE_IP_B1 ec2-user@$PRIVATE_IP_B2

# Or configure in ~/.ssh/config
```

### 7.5 SSH Config File
Add to `~/.ssh/config`:
```
Host vpc-b-public
    HostName <PUBLIC_IP_B>
    User ec2-user
    IdentityFile ~/.ssh/vpc-b-key.pem

Host vpc-b-private-1
    HostName <PRIVATE_IP_B1>
    User ec2-user
    IdentityFile ~/.ssh/vpc-b-key.pem
    ProxyJump vpc-b-public

Host vpc-b-private-2
    HostName <PRIVATE_IP_B2>
    User ec2-user
    IdentityFile ~/.ssh/vpc-b-key.pem
    ProxyJump vpc-b-private-1
```

Then simply run:
```bash
ssh vpc-b-private-2
```

---

## Step 8: Cross-VPC Connectivity Test

### 8.1 Test Connectivity from VPC A to VPC B
```bash
# SSH to VPC A Public VM
ssh -i vpc-a-key.pem ec2-user@$PUBLIC_IP_A

# From VPC A, ping VPC B resources
ping $PRIVATE_IP_B1  # Should work via peering
ping $PRIVATE_IP_B2
```

### 8.2 Test Reverse Connectivity
```bash
# SSH to VPC B Public VM
ssh -i vpc-b-key.pem ec2-user@$PUBLIC_IP_B

# Get VPC A Private VM IP (if exists)
# ping <VPC_A_PRIVATE_IP>
```

---

## Troubleshooting

### Issue: Peering Connection Not Active
```bash
# Check status
aws ec2 describe-vpc-peering-connections \
    --vpc-peering-connection-ids $PEERING_ID \
    --query 'VpcPeeringConnections[0].Status'

# If pending-acceptance, accept in other account
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID
```

### Issue: Cannot Ping Across VPCs
```bash
# Verify route tables have peering routes
aws ec2 describe-route-tables \
    --route-table-ids $RT_PRIVATE_A \
    --query 'RouteTables[0].Routes'

# Check for overlapping CIDRs (must be unique)
# VPC A: 10.0.0.0/16
# VPC B: 10.1.0.0/16

# Verify security groups allow ICMP
aws ec2 authorize-security-group-ingress \
    --group-id $SG_PRIVATE_B1 \
    --protocol icmp --port -1 --cidr 10.0.0.0/16
```

### Issue: SSH Timeout Between Private VMs
```bash
# Check security group chaining
# Private VM 1 SG must allow SSH from Public VM B
# Private VM 2 SG must allow SSH from Private VM 1

# Verify with:
aws ec2 describe-security-groups \
    --group-ids $SG_PRIVATE_B1 \
    --query 'SecurityGroups[0].IpPermissions'
```

---

## Verification Checklist
- [ ] VPC A created with CIDR 10.0.0.0/16
- [ ] VPC B created with CIDR 10.1.0.0/16
- [ ] Subnets created in both VPCs
- [ ] Internet gateways attached
- [ ] Peering connection requested and accepted
- [ ] Route tables updated with peering routes
- [ ] Security groups configured
- [ ] All 4 instances launched
- [ ] Can SSH to Public VM B
- [ ] Can SSH from Public VM B to Private VM 1
- [ ] Can SSH from Private VM 1 to Private VM 2
- [ ] Cross-VPC ping working
- [ ] No CIDR overlaps

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Account A                               │
│                    (Requester Account)                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                      VPC A (10.0.0.0/16)                   │  │
│  │                                                           │  │
│  │   ┌─────────────────┐     ┌─────────────────────────┐    │  │
│  │   │  Public Subnet  │     │      Private Subnet     │    │  │
│  │   │  (10.0.1.0/24)  │     │      (10.0.2.0/24)      │    │  │
│  │   │                 │     │                         │    │  │
│  │   │ ┌─────────────┐ │     │    ┌─────────────┐      │    │  │
│  │   │ │  Public VM  │ │     │    │  Private VM │      │    │  │
│  │   │ │ (Bastion)   │◄┼─────┼────┤  (optional) │      │    │  │
│  │   │ │ 10.0.1.10   │ │     │    │ 10.0.2.10   │      │    │  │
│  │   │ │ Public IP   │ │     │    └─────────────┘      │    │  │
│  │   │ └─────────────┘ │     │                         │    │  │
│  │   │        ↑        │     └─────────────────────────┘    │  │
│  │   │        │        │                                    │  │
│  │   │   IGW-A         │◄────── VPC Peering Connection      │  │
│  │   └─────────────────┘         (pcx-xxxxxxxx)            │  │
│  │                               Status: active              │  │
│  └──────────────────────────────┬──────────────────────────┘  │
└──────────────────────────────────┼─────────────────────────────┘
                                   │
                                   │ Cross-Account Peering
                                   │
┌──────────────────────────────────┼─────────────────────────────┐
│                      AWS Account B                               │
│                     (Accepter Account)                           │
│                                  │                               │
│  ┌───────────────────────────────┼───────────────────────────┐  │
│  │                      VPC B (10.1.0.0/16)                   │  │
│  │                               │                            │  │
│  │   ┌─────────────────┐         │    ┌──────────────────────┐│  │
│  │   │  Public Subnet  │         │    │    Private Subnet 1  ││  │
│  │   │  (10.1.1.0/24)  │         │    │    (10.1.2.0/24)     ││  │
│  │   │                 │         │    │                      ││  │
│  │   │ ┌─────────────┐ │         │    │  ┌───────────────┐   ││  │
│  │   │ │  Public VM  │ │         │    │  │  Private VM 1 │   ││  │
│  │   │ │ 10.1.1.10   │ │◄────────┘    │  │  10.1.2.10    │   ││  │
│  │   │ │ Public IP   │ │              │  └───────┬───────┘   ││  │
│  │   │ └─────────────┘ │              │          │ SSH        ││  │
│  │   │        ↑        │              │          ▼            ││  │
│  │   │        │        │              │  ┌───────────────┐     ││  │
│  │   │   IGW-B         │              │  │  Private VM 2 │     ││  │
│  │   └─────────────────┘              │  │  10.1.3.10    │     ││  │
│  │                                    │  └───────────────┘     ││  │
│  │                                    │      Private Subnet 2   ││  │
│  │                                    │      (10.1.3.0/24)      ││  │
│  │                                    └─────────────────────────┘│  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘

              SSH Flow:
User ──► Public VM B ──► Private VM 1 ──► Private VM 2
```

---

## Cost Considerations

| Component | Cost |
|-----------|------|
| VPC Peering | $0.01/GB data transfer (cross-region) |
| VPC Peering (same region) | Free |
| EC2 Instances | t2.micro: ~$8.50/month each |
| Data Transfer | Within AZ: Free, Cross-AZ: $0.01/GB |

---

**References:**
- [VPC Peering Documentation](https://docs.aws.amazon.com/vpc/latest/peering/)
- [Inter-Region VPC Peering](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)
- [VPC Peering Security](https://docs.aws.amazon.com/vpc/latest/peering/security.html)
