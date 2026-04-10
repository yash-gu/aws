# Bastion-less Access

Use AWS Systems Manager Session Manager instead of bastion hosts.

## 1. Remove Bastion Host

**Console:** EC2 → Instances → Select bastion → Terminate

## 2. Create IAM Role for Session Manager

**Console:** IAM → Roles → Create role
- Trusted entity: EC2
- Policy: `AmazonSSMManagedInstanceCore`
- Name: `SSMRole`

**Console:** IAM → Instance profiles → Create
- Name: `SSMProfile`
- Add role: `SSMRole`

## 3. Create VPC Endpoints (Private Subnets)

**Console:** VPC → Endpoints → Create endpoint
- Service: `com.amazonaws.us-east-1.ssm` (Interface)
- VPC: Your VPC
- Subnets: Private subnet
- Security group: HTTPS (443) from VPC CIDR

Repeat for:
- `com.amazonaws.us-east-1.ec2messages`
- `com.amazonaws.us-east-1.ssmmessages`

## 4. Launch Instance with SSM

**Console:** EC2 → Launch instances
- IAM role: `SSMRole`
- Subnet: Private (no public IP)
- Security group: Allow HTTPS (for SSM)

## 5. Connect via Session Manager

**CLI:** Install Session Manager plugin
```bash
brew install --cask session-manager-plugin
```

**Console:** EC2 → Instances → Select → Connect → Session Manager

**CLI:** Port forwarding
```bash
aws ssm start-session \
    --target <instance-id> \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["80"], "localPortNumber":["8080"]}'
```

## Cleanup

**Console:** EC2 → Instances → Terminate
**Console:** IAM → Roles → Delete `SSMRole`
