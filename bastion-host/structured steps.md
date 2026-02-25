# Bastion Host Network Setup on AWS

This guide creates a VPC with public and private subnets, an internet gateway, a NAT gateway, and routes needed for a bastion host pattern. [web:12][web:16][web:17]

---

## 1. Create a VPC in a Region

1. Open **VPC** service in your chosen region.
2. Go to **Your VPCs** → **Create VPC**.
3. Configure:
   - Name tag: `bastion-host`
   - IPv4 CIDR block: `10.0.0.0/16`
   - IPv6 CIDR block: None
   - Tenancy: Default
4. Click **Create VPC**. [web:16]

Screenshot:  

(images/2.png)

---

## 2. Create Public and Private Subnets in the VPC

1. Go to **Subnets** → **Create subnet**.
2. Select VPC: `bastion-host`. [web:16]

Create **Public Subnet**:
- Name tag: `public-subnet-1`
- Availability Zone: e.g. `ap-south-1a`
- IPv4 CIDR block: `10.0.1.0/24`
- Click **Create subnet**. [web:16]

Create **Private Subnet**:
- Name tag: `private-subnet-1`
- Availability Zone: e.g. `ap-south-1a`
- IPv4 CIDR block: `10.0.2.0/24`
- Click **Create subnet**. [web:16]

Enable auto-assign public IP for the public subnet:
1. Select `public-subnet-1` → **Actions** → **Edit subnet settings**.
2. Enable **Auto-assign public IPv4 address** → Save. [web:12]

Screenshots:  

(images/3.png)  
(images/4.png)  
(images/5.png)

---

## 3. Create an Internet Gateway

1. Go to **Internet gateways** → **Create internet gateway**.
2. Name tag: `bastion-igw`.
3. Click **Create internet gateway**.
4. Select `bastion-igw` → **Actions** → **Attach to VPC** → choose `bastion-host`. [web:14]

Screenshot:  

(images/6.png)

---

## 4. Attach Internet Gateway to Public Subnet (via Route Table)

1. Go to **Route tables**.
2. Create a new route table:
   - Name tag: `public-rt`
   - VPC: `bastion-host`
   - Click **Create route table**. [web:17]

Associate with the public subnet:
1. Select `public-rt` → **Subnet associations** → **Edit subnet associations**.
2. Check `public-subnet-1` → **Save associations**. [web:17]

Add default route to IGW:
1. With `public-rt` selected → **Routes** → **Edit routes** → **Add route**.
2. Destination: `0.0.0.0/0`.
3. Target: `Internet Gateway` → `bastion-igw`.
4. **Save changes**. [web:14][web:17]

Screenshots:  

(images/7.png)  
(images/8.png)

---

## 5. Create Routing Table for Public Subnet

(Already created as `public-rt` above; this section confirms its config.) [web:17]

Ensure:
- **Associated subnet**: `public-subnet-1`.
- **Routes**:
  - `10.0.0.0/16` → local
  - `0.0.0.0/0` → `bastion-igw`. [web:14][web:17]

Screenshots:  

(images/9.png)  
(images/10.png)

---

## 6. Create a NAT Gateway in the Public Subnet

1. First allocate an Elastic IP:
   - Go to **EC2** → **Network & Security** → **Elastic IPs** → **Allocate Elastic IP address** → **Allocate**. [web:6]
2. Go to **VPC** → **NAT gateways** → **Create NAT gateway**.
3. Configure:
   - Name: `bastion-nat-gw`
   - Subnet: `public-subnet-1`
   - Elastic IP allocation ID: select the allocated Elastic IP
4. Click **Create NAT gateway** and wait until status is **Available**. [web:6][web:16]

Screenshots:  

(images/11.png)  
(images/12.png)

---

## 7. Connect NAT Gateway to Private Subnet via Route Table

Create private route table:
1. Go to **Route tables** → **Create route table**.
2. Name tag: `private-rt`.
3. VPC: `bastion-host`.
4. Click **Create route table**. [web:17]

Associate with private subnet:
1. Select `private-rt` → **Subnet associations** → **Edit subnet associations**.
2. Check `private-subnet-1` → **Save associations**. [web:17]

Add route to NAT gateway:
1. With `private-rt` selected → **Routes** → **Edit routes** → **Add route**.
2. Destination: `0.0.0.0/0`.
3. Target: `NAT gateway` → `bastion-nat-gw`.
4. **Save changes**. [web:6][web:16][web:17]

Screenshot:  

(images/13.png)

---

Now:
- The public subnet has direct internet access via the internet gateway (for the bastion host). [web:14]
- The private subnet has outbound internet via the NAT gateway but no direct inbound internet access. [web:6][web:16]
