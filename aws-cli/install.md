# AWS CLI Infrastructure Setup Guide

This guide walks through creating AWS infrastructure **using only AWS CLI**, including:

- S3 Bucket
- Custom VPC
- Public & Private Subnets
- Internet Gateway
- NAT Gateway
- Route Tables
- Security Groups
- EC2 Instances (Nginx via User Data)
- Application Load Balancer (ALB)
- Target Registration & Testing

---

# Prerequisites

- AWS CLI installed
- AWS CLI configured (`aws configure`)
- IAM user with required permissions

---

# PART 1: Install AWS CLI

## Linux / macOS

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install