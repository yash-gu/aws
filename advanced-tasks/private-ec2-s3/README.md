# Private EC2 with S3 Access

Private EC2 (no internet) that can access S3 via VPC Endpoint.

## 1. Create Private VPC

**Console:** VPC → Create VPC
- CIDR: 10.0.0.0/16
- Create subnet: 10.0.1.0/24 (private, no auto-assign public IP)
- No internet gateway

## 2. Create S3 VPC Endpoint

**Console:** VPC → Endpoints → Create endpoint
- Service category: AWS services
- Service: `com.amazonaws.us-east-1.s3`
- Type: Gateway
- VPC: Your VPC
- Route tables: Select private route table

## 3. Create IAM Role

**Console:** IAM → Roles → Create role
- Trusted entity: EC2
- Policy: AmazonS3ReadOnlyAccess
- Name: `PrivateEC2Role`

## 4. Launch Private EC2

**Console:** EC2 → Launch instances
- Name: Private EC2
- IAM role: `PrivateEC2Role`
- Subnet: Private subnet (no public IP)
- Security group: Allow HTTPS (for SSM)

## 5. Test S3 Access

**Console:** EC2 → Instances → Connect → Session Manager

Inside the instance:
```bash
ping google.com  # fails - no internet
aws s3 ls        # works - via VPC endpoint
aws s3 cp s3://bucket/file.txt .  # works
```

## Cleanup

**Console:** EC2 → Instances → Terminate
**Console:** VPC → Endpoints → Delete endpoint
**Console:** IAM → Roles → Delete `PrivateEC2Role`
