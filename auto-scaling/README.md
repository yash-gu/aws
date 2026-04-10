# Auto Scaling Group Setup with Application Load

## Overview
This guide covers creating an EC2 instance, installing a web application, creating an AMI, setting up Launch Templates, Auto Scaling Groups, and applying scaling policies.

![Auto Scaling Architecture](https://docs.aws.amazon.com/images/autoscaling/ec2/userguide/images/auto-scaling-overview.png)

## Prerequisites
- AWS Account
- VPC with public subnets in multiple AZs
- Basic understanding of EC2 and Load Balancers

---

## Step 1: Create EC2 Instance with Web App

### 1.1 Launch Base EC2 Instance
| Setting | Value |
|---------|-------|
| **Name** | `webapp-base-instance` |
| **AMI** | Amazon Linux 2023 |
| **Instance Type** | t2.micro |
| **VPC** | Your VPC |
| **Subnet** | Public subnet |
| **Security Group** | Allow HTTP (80), SSH (22) |

### 1.2 Connect and Install Web Application
```bash
# SSH to instance
ssh -i my-key.pem ec2-user@<PUBLIC_IP>

# Update system
sudo dnf update -y

# Install Nginx
sudo dnf install nginx -y

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 1.3 Create Custom Web Application
```bash
# Create a custom index page showing instance metadata
sudo tee /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Auto Scaling Demo</title>
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
            margin: 20px;
        }
    </style>
</head>
<body>
    <h1>Auto Scaling Web Application</h1>
    <div class="info-box">
        <h2>Server Information</h2>
        <p><strong>Instance ID:</strong> <!--#echo var="INSTANCE_ID" --></p>
        <p><strong>Availability Zone:</strong> <!--#echo var="AZ" --></p>
        <p><strong>Private IP:</strong> <!--#echo var="LOCAL_ADDR" --></p>
        <p><strong>Hostname:</strong> <span id="hostname"></span></p>
    </div>
    <script>
        document.getElementById('hostname').textContent = window.location.hostname;
    </script>
</body>
</html>
EOF

# Enable server-side includes in Nginx
sudo sed -i 's/index  index.html/index  index.html index.shtml/g' /etc/nginx/nginx.conf

# Reload Nginx
sudo systemctl reload nginx
```

### 1.4 Add Files and Directories
```bash
# Create application directories
sudo mkdir -p /var/www/app/{logs,data,uploads}

# Set permissions
sudo chown -R ec2-user:ec2-user /var/www/app

# Create sample files
echo "App configuration" | sudo tee /var/www/app/config.txt
sudo dd if=/dev/urandom of=/var/www/app/data/sample.dat bs=1M count=10
```

### 1.5 Verify Web App
```bash
# Test locally
curl localhost

# Should see custom page
```

---

## Step 2: Create AMI (Amazon Machine Image)

### 2.1 Stop the Instance (Recommended)
```bash
# In AWS Console or CLI
aws ec2 stop-instances --instance-ids i-xxxxxxxxxxxxx
```

### 2.2 Create AMI
1. Go to **EC2 Console** → **Instances**
2. Select your instance → **Actions** → **Image and templates** → **Create image**
3. Configure:

| Setting | Value |
|---------|-------|
| **Image name** | `webapp-ami-v1` |
| **Image description** | `Web application with Nginx - v1.0` |
| **No reboot** | Unchecked (reboots for consistency) |
| **Instance volumes** | Keep defaults |

4. Click **Create image**

![Create AMI](https://docs.aws.amazon.com/images/AWSEC2/latest/UserGuide/images/creating-an-ami.png)

### 2.3 Monitor AMI Creation
1. Navigate to **AMIs** in EC2 Console
2. Wait for status to change from **Pending** to **Available**
3. Note the AMI ID: `ami-xxxxxxxxxxxxxxxxx`

### 2.4 AMI Creation via CLI
```bash
aws ec2 create-image \
    --instance-id i-xxxxxxxxxxxxx \
    --name "webapp-ami-v1" \
    --description "Web application with Nginx - v1.0" \
    --no-reboot

# Check status
aws ec2 describe-images --image-ids ami-xxxxxxxxxxxxxxxxx
```

---

## Step 3: Create Launch Template

### 3.1 Navigate to Launch Templates
1. Go to **EC2 Console** → **Launch Templates**
2. Click **Create launch template**

### 3.2 Configure Launch Template
| Setting | Value |
|---------|-------|
| **Launch template name** | `webapp-launch-template` |
| **Template version description** | `v1 - Web App with Nginx` |
| **Auto scaling guidance** | Check the box |

#### Launch Template Content:
| Setting | Value |
|---------|-------|
| **Application and OS Images** | My AMIs → `webapp-ami-v1` |
| **Instance type** | t2.micro |
| **Key pair** | Your key pair |
| **VPC** | Your VPC |

#### Network Settings:
| Setting | Value |
|---------|-------|
| **Subnet** | Don't include in template (ASG will specify) |
| **Auto-assign public IP** | Enable |
| **Security groups** | WebApp-SG (allow 80, 443, 22) |
| **Tags** | Name: `webapp-asg-instance` |

### 3.3 Advanced Details (Optional)
```bash
# User data for additional boot-time configuration
#!/bin/bash
echo "Instance started at $(date)" >> /var/log/startup.log
systemctl start nginx
```

### 3.4 Create Launch Template
Click **Create launch template**

![Launch Template](https://docs.aws.amazon.com/images/autoscaling/ec2/userguide/images/launch-template-diagram.png)

---

## Step 4: Create Auto Scaling Group

### 4.1 Navigate to Auto Scaling
1. Go to **EC2 Console** → **Auto Scaling Groups**
2. Click **Create Auto Scaling group**

### 4.2 Step 1: Choose Launch Template
| Setting | Value |
|---------|-------|
| **Auto Scaling group name** | `webapp-asg` |
| **Launch template** | `webapp-launch-template` |
| **Version** | Latest |

### 4.3 Step 2: Choose Instance Launch Options
| Setting | Value |
|---------|-------|
| **VPC** | Your custom VPC |
| **Availability Zones and subnets** | Select 2+ subnets in different AZs |
| Example | Public-1a, Public-1b, Public-1c |

### 4.4 Step 3: Configure Advanced Options

#### Load Balancing
| Setting | Value |
|---------|-------|
| **Attach to existing load balancer** | Create new ALB |
| **Load balancer name** | `webapp-alb` |
| **Scheme** | Internet-facing |
| **Load balancer type** | Application Load Balancer |

#### Health Checks
| Setting | Value |
|---------|-------|
| **Health check type** | ELB |
| **Health check grace period** | 300 seconds |

### 4.5 Step 4: Configure Group Size and Scaling

#### Group Size
| Setting | Value | Description |
|---------|-------|-------------|
| **Desired capacity** | 2 | Start with 2 instances |
| **Minimum capacity** | 2 | Never go below 2 |
| **Maximum capacity** | 6 | Never exceed 6 |

#### Scaling Policies - Create Target Tracking Policy
| Setting | Value |
|---------|-------|
| **Scaling policy name** | `target-tracking-cpu` |
| **Metric type** | Average CPU utilization |
| **Target value** | 50 |
| **Instances need** | 300 seconds to warm up |

### 4.6 Step 5: Add Notifications (Optional)
Configure SNS notifications for scaling events.

### 4.7 Step 6: Add Tags
| Key | Value | Propagate |
|-----|-------|-----------|
| Name | webapp-asg-instance | ✓ |
| Environment | production | ✓ |
| ManagedBy | AutoScaling | ✓ |

### 4.8 Create Auto Scaling Group
Click **Create Auto Scaling group**

---

## Step 5: Apply Additional Scaling Policies

### 5.1 Step Scaling Policy (CPU Based)
```bash
# Create step scaling policy via CLI
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name webapp-asg \
    --policy-name cpu-step-scale-up \
    --policy-type StepScaling \
    --adjustment-type ChangeInCapacity \
    --metric-type ASGAverageCPUUtilization \
    --target-value 70 \
    --step-adjustments MetricIntervalLowerBound=0,ScalingAdjustment=1
```

### 5.2 Create CloudWatch Alarms
```bash
# Scale Up Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name WebApp-HighCPU \
    --alarm-description "CPU > 70% for 2 minutes" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 120 \
    --threshold 70 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=AutoScalingGroupName,Value=webapp-asg \
    --evaluation-periods 2

# Scale Down Alarm  
aws cloudwatch put-metric-alarm \
    --alarm-name WebApp-LowCPU \
    --alarm-description "CPU < 30% for 10 minutes" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 600 \
    --threshold 30 \
    --comparison-operator LessThanThreshold \
    --dimensions Name=AutoScalingGroupName,Value=webapp-asg \
    --evaluation-periods 2
```

### 5.3 Scheduled Scaling (Optional)
```bash
# Scale up every day at 9 AM
aws autoscaling put-scheduled-update-group-action \
    --auto-scaling-group-name webapp-asg \
    --scheduled-action-name scale-up-morning \
    --recurrence "0 9 * * *" \
    --min-size 4 \
    --desired-capacity 4 \
    --max-size 6

# Scale down every day at 6 PM
aws autoscaling put-scheduled-update-group-action \
    --auto-scaling-group-name webapp-asg \
    --scheduled-action-name scale-down-evening \
    --recurrence "0 18 * * *" \
    --min-size 2 \
    --desired-capacity 2 \
    --max-size 6
```

### 5.4 Predictive Scaling (Advanced)
```bash
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name webapp-asg \
    --policy-name predictive-cpu-policy \
    --policy-type PredictiveScaling \
    --predictive-scaling-configuration file://predictive-scaling-config.json
```

---

## Step 6: Verify Auto Scaling Setup

### 6.1 Check Running Instances
```bash
# List instances in ASG
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names webapp-asg

# Should see desired number of instances
```

### 6.2 Check Load Balancer
1. Go to **EC2** → **Load Balancers**
2. Select `webapp-alb`
3. Copy **DNS name** (e.g., `webapp-alb-123456.us-east-1.elb.amazonaws.com`)
4. Access in browser: `http://webapp-alb-123456.us-east-1.elb.amazonaws.com`

### 6.3 Test Load Distribution
Refresh the page multiple times - you should see different instance IDs if multiple instances are serving requests.

### 6.4 Test Scaling
```bash
# Generate load to trigger scaling
# Install siege: sudo dnf install siege -y

siege -c 100 -t 5M http://webapp-alb-123456.us-east-1.elb.amazonaws.com/
```

---

## Troubleshooting

### Issue: Instances Not Launching
```bash
# Check:
1. AMI is available in the region
2. Subnets have enough IPs
3. IAM roles allow EC2 creation
4. Launch template has valid configuration

# View scaling activities
aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name webapp-asg
```

### Issue: Health Checks Failing
```bash
# Check health check configuration
# Ensure security group allows health check port
# Verify application is listening on correct port

# View instance health
aws autoscaling describe-auto-scaling-instances
```

### Issue: Load Balancer 502 Errors
```bash
# Check target group health
# Ensure security groups allow traffic from ALB
# Verify instances are in healthy state

aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...
```

---

## Verification Checklist
- [ ] Base EC2 instance created with web app
- [ ] AMI created from base instance
- [ ] Launch template created with AMI
- [ ] Auto Scaling Group created
- [ ] Multiple subnets/AZs configured
- [ ] Load balancer attached (optional)
- [ ] Scaling policies configured
- [ ] Instances are launching
- [ ] Website accessible via ALB DNS
- [ ] Scaling triggered under load

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                    │
│         webapp-alb-xxx.us-east-1.elb.amazonaws.com              │
│              Port 80 → Target Group                             │
└──────────────┬─────────────────────────────┬────────────────────┘
               │                             │
               │ Health Checks               │
               ▼                             ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      Availability       │     │      Availability       │
│       Zone A            │     │       Zone B            │
│  ┌─────────────────┐   │     │  ┌─────────────────┐   │
│  │   EC2 Instance  │   │     │  │   EC2 Instance  │   │
│  │   (From AMI)    │   │     │  │   (From AMI)    │   │
│  │   ┌───────────┐ │   │     │  │   ┌───────────┐ │   │
│  │   │   Nginx   │ │   │     │  │   │   Nginx   │ │   │
│  │   │  Web App  │ │   │     │  │   │  Web App  │ │   │
│  │   └───────────┘ │   │     │  │   └───────────┘ │   │
│  └─────────────────┘   │     │  └─────────────────┘   │
│                         │     │                         │
└──────────┬──────────────┘     └──────────┬──────────────┘
           │                                │
           └────────┬───────────────────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │   Auto Scaling      │
         │      Group          │
         │  ┌───────────────┐  │
         │  │ Min: 2       │  │
         │  │ Desired: 2   │  │
         │  │ Max: 6       │  │
         │  └───────────────┘  │
         │                     │
         │  Launch Template    │
         │  + Scaling Policies │
         └─────────────────────┘
```

---

## Scaling Policies Reference

| Policy Type | Use Case | Trigger |
|-------------|----------|---------|
| **Target Tracking** | Maintain metric at target | CPU, ALB requests |
| **Step Scaling** | Respond to CloudWatch alarms | Custom thresholds |
| **Scheduled Scaling** | Predictable changes | Date/time based |
| **Predictive Scaling** | ML-based forecasting | Traffic patterns |

---

## Cleanup
```bash
# Delete in order:
1. Auto Scaling Group (terminates instances)
2. Load Balancer
3. Target Groups
4. Launch Template
5. AMI (deregister)
6. EBS snapshots (if no longer needed)
```

---

**References:**
- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [Launch Templates](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html)
- [Scaling Policies](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html)
