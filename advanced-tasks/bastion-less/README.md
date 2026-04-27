# Bastion-less Access

Use AWS Systems Manager Session Manager instead of bastion hosts.

## 1. Remove Bastion Host

EC2 → Instances → Select bastion → Terminate

## 2. Create IAM Role for Session Manager

IAM → Roles → Create role
- Trusted entity: EC2
- Policy: `AmazonSSMManagedInstanceCore`
- Name: `SSMRole`

 IAM → Instance profiles → Create
- Name: `SSMProfile`
- Add role: `SSMRole`

## 3. Create VPC Endpoints (Private Subnets)
 VPC → Endpoints → Create endpoint
- Service: `com.amazonaws.us-east-1.ssm` (Interface)
- VPC: Your VPC
- Subnets: Private subnet
- Security group: HTTPS (443) from VPC CIDR

Repeat for:
- `com.amazonaws.us-east-1.ec2messages`
- `com.amazonaws.us-east-1.ssmmessages`

## 4. Launch Instance with SSM
EC2 → Launch instances
- IAM role: `SSMRole`
- Subnet: Private (no public IP)
- Security group: Allow HTTPS (for SSM)

## 5. Connect via Session Manager
EC2 → Instances → Select → Connect → Session Manager

