# RDS Deployment

Deploy MySQL RDS in private subnet with Multi-AZ.

## 1. Create DB Subnet Group

**Console:** RDS → Subnet groups → Create DB subnet group
- Name: `my-db-subnet-group`
- VPC: Select your VPC
- Availability zones: 2 zones
- Subnets: Private subnets

## 2. Create RDS Security Group

**Console:** EC2 → Security groups → Create security group
- Name: `rds-mysql-sg`
- VPC: Your VPC
- Inbound rules:
  - Type: MySQL (3306)
  - Source: EC2 security group (app servers)

## 3. Create RDS Instance

**Console:** RDS → Create database
- Engine: MySQL
- Template: Production (Multi-AZ)
- DB identifier: `my-mysql-db`
- Instance: db.t3.micro
- Master username: admin
- Password: auto-generate
- VPC: Your VPC
- Subnet group: `my-db-subnet-group`
- Security group: `rds-mysql-sg`
- Public access: No
- Backup: 7 days

## 4. Get Endpoint

**Console:** RDS → Databases → `my-mysql-db` → Connectivity & security
- Endpoint: `my-mysql-db.xxxxx.us-east-1.rds.amazonaws.com`

## 5. Connect from EC2

```bash
# Install MySQL client
sudo yum install -y mariadb105

# Connect
mysql -h my-mysql-db.xxxxx.us-east-1.rds.amazonaws.com -u admin -p
```

## Cleanup

**Console:** RDS → Databases → `my-mysql-db` → Actions → Delete
- Skip final snapshot
