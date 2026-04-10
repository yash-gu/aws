# Application Load Balancer (ALB) Setup

## Overview
This guide covers creating an Application Load Balancer, registering targets, and troubleshooting common issues like Bad Gateway errors and target health problems.

![ALB Architecture](https://docs.aws.amazon.com/images/elasticloadbalancing/latest/application/images/load_balancer_subnets.png)

## Prerequisites
- VPC with at least 2 public subnets in different AZs
- EC2 instances running web application
- Security groups configured

---

## Step 1: Create Application Load Balancer

### 1.1 Navigate to Load Balancers
1. Go to **EC2 Console** → **Load Balancers**
2. Click **Create load balancer**
3. Select **Application Load Balancer**

### 1.2 Basic Configuration
| Setting | Value |
|---------|-------|
| **Load balancer name** | `my-app-alb` |
| **Scheme** | Internet-facing |
| **IP address type** | IPv4 |
| **VPC** | Your VPC |
| **Mappings** | Select at least 2 subnets in different AZs |

Example mapping:
| AZ | Subnet |
|----|--------|
| us-east-1a | Public-1a |
| us-east-1b | Public-1b |

### 1.3 Security Groups
Create or select a security group with:

| Type | Protocol | Port | Source |
|------|----------|------|--------|
| HTTP | TCP | 80 | 0.0.0.0/0 |
| HTTPS | TCP | 443 | 0.0.0.0/0 |

![ALB Security Group](https://docs.aws.amazon.com/images/elasticloadbalancing/latest/application/images/security-group.png)

### 1.4 Listeners and Routing
| Listener | Port | Target Group |
|----------|------|--------------|
| HTTP | 80 | Create new target group |

### 1.5 Create Target Group (during ALB creation)
| Setting | Value |
|---------|-------|
| **Target type** | Instances |
| **Target group name** | `web-servers-tg` |
| **Protocol** | HTTP |
| **Port** | 80 |
| **VPC** | Your VPC |
| **Protocol version** | HTTP/1.1 |

#### Health Check Settings:
| Setting | Value |
|---------|-------|
| **Health check protocol** | HTTP |
| **Health check path** | / |
| **Healthy threshold** | 2 consecutive successes |
| **Unhealthy threshold** | 3 consecutive failures |
| **Timeout** | 5 seconds |
| **Interval** | 30 seconds |
| **Success code** | 200 |

### 1.6 Register Targets
Select your EC2 instances and click **Include as pending below**

### 1.7 Create Load Balancer
Click **Create load balancer**

---

## Step 2: Register Additional Targets

### 2.1 Add Targets to Existing Target Group
1. Go to **EC2** → **Target Groups**
2. Select your target group (`web-servers-tg`)
3. Click **Targets** tab → **Register targets**
4. Select instances → **Include as pending** → **Register pending targets**

### 2.2 Register via CLI
```bash
# Register targets
aws elbv2 register-targets \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/web-servers-tg/xxx \
    --targets Id=i-1234567890abcdef0 Id=i-0987654321fedcba0

# Deregister targets
aws elbv2 deregister-targets \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/web-servers-tg/xxx \
    --targets Id=i-1234567890abcdef0
```

### 2.3 Verify Target Registration
```bash
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/web-servers-tg/xxx
```

---

## Step 3: Verify ALB Setup

### 3.1 Check Load Balancer DNS
1. Go to **EC2** → **Load Balancers**
2. Select your ALB
3. Copy the **DNS name** (e.g., `my-app-alb-123456789.us-east-1.elb.amazonaws.com`)

### 3.2 Test in Browser
```
http://my-app-alb-123456789.us-east-1.elb.amazonaws.com
```

### 3.3 Test with curl
```bash
curl -I http://my-app-alb-123456789.us-east-1.elb.amazonaws.com
curl http://my-app-alb-123456789.us-east-1.elb.amazonaws.com
```

### 3.4 Check Target Health
1. Go to **Target Groups** → Select your TG
2. Click **Targets** tab
3. Verify status shows **healthy**

![Target Health](https://docs.aws.amazon.com/images/elasticloadbalancing/latest/application/images/target-health.png)

---

## Step 4: Troubleshooting Bad Gateway (502) Errors

### 4.1 Common Causes and Solutions

#### Cause 1: Target Not Responding
```bash
# Check if application is running on target
ssh -i my-key.pem ec2-user@<INSTANCE_IP>
sudo systemctl status nginx  # or your web server
curl localhost  # Test locally

# Fix: Start the application
sudo systemctl start nginx
```

#### Cause 2: Wrong Health Check Path
```bash
# Verify the health check path exists
# Default is / - must return HTTP 200

# Update target group health check:
# Target Groups → web-servers-tg → Health checks → Edit
```

#### Cause 3: Security Group Blocking Traffic
```bash
# Instance security group must allow traffic from ALB
# Check instance security group inbound rules:

# Should have:
# HTTP (80) from ALB Security Group (not IP!)

# Get ALB security group ID
aws elbv2 describe-load-balancers \
    --names my-app-alb \
    --query 'LoadBalancers[0].SecurityGroups'

# Update instance security group
aws ec2 authorize-security-group-ingress \
    --group-id sg-instance-sg \
    --protocol tcp --port 80 \
    --source-group sg-alb-sg
```

#### Cause 4: Wrong Port Configuration
```bash
# Verify target group port matches application port
# If app runs on port 8080, target group port should be 8080

# Update target group port
aws elbv2 modify-target-group \
    --target-group-arn arn:aws:elasticloadbalancing:... \
    --port 8080
```

### 4.2 Enable ALB Access Logs
```bash
# Create S3 bucket for logs
aws s3 mb s3://my-alb-logs-bucket

# Enable access logs
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn arn:aws:elasticloadbalancing:... \
    --attributes Key=access_logs.s3.enabled,Value=true \
               Key=access_logs.s3.bucket,Value=my-alb-logs-bucket
```

---

## Step 5: Troubleshooting Target Health Issues

### 5.1 Target Stuck in "Initial" State
```bash
# Check if target is in correct VPC
aws elbv2 describe-target-groups \
    --target-group-arns arn:aws:elasticloadbalancing:... \
    --query 'TargetGroups[0].VpcId'

# Verify instance is in the same VPC
aws ec2 describe-instances \
    --instance-ids i-xxx \
    --query 'Reservations[0].Instances[0].VpcId'
```

### 5.2 Target Showing "Unhealthy"

#### Step-by-Step Diagnosis:
```bash
# 1. Check security groups
echo "Instance Security Group:"
aws ec2 describe-instances --instance-ids i-xxx \
    --query 'Reservations[0].Instances[0].SecurityGroups'

echo "ALB Security Group:"
aws elbv2 describe-load-balancers --names my-app-alb \
    --query 'LoadBalancers[0].SecurityGroups'

# 2. Test health check from another instance in same VPC
ssh -i key.pem ec2-user@<OTHER_INSTANCE>
curl http://<TARGET_PRIVATE_IP>:80/health  # or /

# 3. Check application logs
ssh -i key.pem ec2-user@<TARGET_IP>
sudo tail -f /var/log/nginx/error.log
```

#### Common Fixes:

**Fix 1: Update Health Check Path**
```bash
# Target Groups → web-servers-tg → Health checks → Edit
# If your app has /health endpoint, use that instead of /

aws elbv2 modify-target-group \
    --target-group-arn arn:aws:elasticloadbalancing:... \
    --health-check-path /health \
    --health-check-port 80
```

**Fix 2: Adjust Health Check Intervals**
```bash
# For slow-starting applications, increase timeout
aws elbv2 modify-target-group \
    --target-group-arn arn:aws:elasticloadbalancing:... \
    --health-check-interval-seconds 60 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 3
```

**Fix 3: Fix Security Group**
```bash
# Instance SG must allow port from ALB SG
aws ec2 authorize-security-group-ingress \
    --group-id sg-instance-sg \
    --protocol tcp --port 80 \
    --source-group sg-alb-sg \
    --description "Allow from ALB"
```

### 5.3 Target Showing "Unused"
```bash
# Target is not associated with any ALB listener rule
# Check target group is registered with ALB

aws elbv2 describe-listeners \
    --load-balancer-arn arn:aws:elasticloadbalancing:...

# If not registered, update listener
aws elbv2 modify-listener \
    --listener-arn arn:aws:elasticloadbalancing:... \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...
```

---

## Step 6: Advanced ALB Configuration

### 6.1 Enable HTTPS/SSL
```bash
# Request certificate from ACM
aws acm request-certificate \
    --domain-name example.com \
    --validation-method DNS \
    --subject-alternative-names www.example.com

# Create HTTPS listener
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:... \
    --protocol HTTPS --port 443 \
    --certificates CertificateArn=arn:aws:acm:... \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...

# Redirect HTTP to HTTPS
aws elbv2 create-rule \
    --listener-arn arn:aws:elasticloadbalancing:... \
    --priority 1 \
    --conditions Field=path-pattern,PathPatternConfig='{"Values":["/"]}' \
    --actions Type=redirect,RedirectConfig='{"Protocol":"HTTPS","Port":"443","StatusCode":"HTTP_301"}'
```

### 6.2 Enable Sticky Sessions
```bash
aws elbv2 modify-target-group-attributes \
    --target-group-arn arn:aws:elasticloadbalancing:... \
    --attributes Key=stickiness.enabled,Value=true \
               Key=stickiness.type,Value=lb_cookie \
               Key=stickiness.lb_cookie.duration_seconds,Value=86400
```

### 6.3 Enable Slow Start Mode
```bash
# Gradually increase traffic to new targets
aws elbv2 modify-target-group-attributes \
    --target-group-arn arn:aws:elasticloadbalancing:... \
    --attributes Key=slow_start.duration_seconds,Value=30
```

---

## Step 7: Monitoring ALB

### 7.1 CloudWatch Metrics
| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| RequestCount | Total requests | - |
| TargetResponseTime | Backend latency | > 2 seconds |
| HTTPCode_Target_5XX_Count | Backend 5xx errors | > 0 |
| HTTPCode_ELB_5XX_Count | ALB 5xx errors | > 0 |
| HealthyHostCount | Healthy targets | < minimum |
| UnHealthyHostCount | Unhealthy targets | > 0 |
| ActiveConnectionCount | Active connections | - |
| RejectedConnectionCount | Rejected connections | > 0 |

### 7.2 View Metrics
```bash
# Get metric statistics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name TargetResponseTime \
    --dimensions Name=LoadBalancer,Value=app/my-app-alb/xxx \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-01T01:00:00Z \
    --period 300 \
    --statistics Average
```

### 7.3 Enable Access Logging
```bash
# Already covered in step 4.2
# View logs in S3 or use Athena to query
```

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| **502 Bad Gateway** | Target not responding | Check app status, security groups |
| **503 Service Unavailable** | No healthy targets | Check target health, deregistration delay |
| **504 Gateway Timeout** | Target slow to respond | Increase idle timeout, check app performance |
| **Target: Initial** | Still registering | Wait 2-3 health check intervals |
| **Target: Unhealthy** | Health check failing | Verify health endpoint, security groups |
| **Target: Unused** | Not in listener rule | Add to target group in listener |
| **High latency** | Backend slow | Scale up, optimize application |
| **Connection refused** | Security group blocking | Allow ALB SG in instance SG |

---

## Verification Checklist
- [ ] ALB created with 2+ subnets
- [ ] Security group allows HTTP/HTTPS
- [ ] Target group created with correct port
- [ ] Health check path returns 200
- [ ] Instances registered as targets
- [ ] Targets showing "healthy" status
- [ ] Website accessible via ALB DNS
- [ ] Load is distributed across targets
- [ ] Access logs enabled (optional)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Application Load Balancer                          │
│              my-app-alb-xxx.us-east-1.elb.amazonaws.com        │
│                                                                  │
│  Listeners:                                                      │
│  ├─ HTTP:80  → Target Group (web-servers-tg)                   │
│  └─ HTTPS:443 → Target Group (web-servers-tg) [optional]       │
│                                                                  │
│  Security Group:                                                 │
│  ├─ Allow: HTTP from 0.0.0.0/0                                   │
│  └─ Allow: HTTPS from 0.0.0.0/0                                  │
└──────────────┬─────────────────────────────┬────────────────────┘
               │ Health Check                │
               │ / (every 30s)               │
               ▼                             ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      Availability       │     │      Availability       │
│       Zone A            │     │       Zone B            │
│  ┌─────────────────┐   │     │  ┌─────────────────┐   │
│  │   EC2 Instance  │   │     │  │   EC2 Instance  │   │
│  │  Target: i-xxx  │   │     │  │  Target: i-yyy  │   │
│  │  Health: healthy│   │     │  │  Health: healthy│   │
│  │  Port: 80       │   │     │  │  Port: 80       │   │
│  │                 │   │     │  │                 │   │
│  │ Security Group: │   │     │  │ Security Group: │   │
│  │ ├─ SSH (22)     │   │     │  │ ├─ SSH (22)     │   │
│  │ └─ HTTP (80)    │   │     │  │ └─ HTTP (80)    │   │
│  │    from ALB SG  │   │     │  │    from ALB SG  │   │
│  └─────────────────┘   │     │  └─────────────────┘   │
└─────────────────────────┘     └─────────────────────────┘
```

---

**References:**
- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [Troubleshooting](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-troubleshooting.html)
