# Jenkins Cloud Plugin & Auto-Scaling Integration

## Overview
This guide covers configuring Jenkins with AWS EC2 cloud plugin for dynamic agent provisioning and auto-scaling integration.

![Jenkins EC2 Architecture](https://www.jenkins.io/images/post-images/2019-02-27-cloud-native-jenkins/jenkins-on-aws.png)

## Prerequisites
- Running Jenkins server (EC2 or self-hosted)
- AWS Account with IAM permissions
- Basic understanding of Jenkins pipelines

---

## Step 1: Install Jenkins

### 1.1 Launch EC2 for Jenkins Master
| Setting | Value |
|---------|-------|
| **AMI** | Ubuntu Server 22.04 LTS |
| **Instance Type** | t3.medium (minimum for Jenkins) |
| **Storage** | 20 GB GP2/3 |
| **Security Group** | Ports 22, 80, 8080 |

### 1.2 Install Jenkins on Ubuntu
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java (required for Jenkins)
sudo apt install openjdk-17-jre -y

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install jenkins -y

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Check status
sudo systemctl status jenkins
```

### 1.3 Initial Setup
```bash
# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

1. Navigate to `http://<EC2_PUBLIC_IP>:8080`
2. Enter initial admin password
3. Install suggested plugins
4. Create admin user

![Jenkins Setup](https://www.jenkins.io/images/getting-started-setup.png)

---

## Step 2: Configure AWS Credentials

### 2.1 Create IAM Policy for Jenkins
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:CreateTags",
                "ec2:DeleteTags",
                "ec2:DescribeSpotInstanceRequests",
                "ec2:RequestSpotInstances",
                "ec2:CancelSpotInstanceRequests",
                "ec2:DescribeImages",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
```

### 2.2 Create IAM User
1. Go to **IAM** → **Users** → **Create user**
2. Name: `jenkins-ec2-user`
3. Attach the policy created above
4. Generate **Access Key ID** and **Secret Access Key**

### 2.3 Add Credentials to Jenkins
1. Navigate to **Manage Jenkins** → **Manage Credentials**
2. Click **(global)** → **Add Credentials**
3. Select **AWS Credentials**:
   - **ID**: `aws-jenkins-credentials`
   - **Access Key ID**: Your access key
   - **Secret Access Key**: Your secret key

---

## Step 3: Install EC2 Plugin

### 3.1 Install Plugin
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Click **Available** tab
3. Search for **Amazon EC2**
4. Check the box and click **Install without restart**

![EC2 Plugin](https://plugins.jenkins.io/ec2/images/ec2-plugin.png)

---

## Step 4: Configure EC2 Cloud

### 4.1 Add New Cloud
1. Navigate to **Manage Jenkins** → **Clouds**
2. Click **New Cloud**
3. Name: `aws-ec2-cloud`
4. Type: **Amazon EC2**
5. Click **Create**

### 4.2 Configure Cloud Settings
| Setting | Value | Description |
|---------|-------|-------------|
| **Region** | us-east-1 | Your AWS region |
| **Credentials** | aws-jenkins-credentials | IAM user credentials |
| **EC2 Key Pair's Private Key** | Paste private key | For SSH to agents |

### 4.3 Configure AMI
Create a template with the following settings:

| Setting | Value |
|---------|-------|
| **Description** | `jenkins-agent-ubuntu` |
| **AMI ID** | ami-0c7217cdde317cfec (Ubuntu 22.04) |
| **Instance Type** | t3.small |
| **Remote user** | ubuntu |
| **Root command prefix** | sudo |
| **Remote ssh port** | 22 |
| **Labels** | `ubuntu-agent` |
| **Usage** | Use this node as much as possible |
| **Idle termination time** | 30 (minutes) |

### 4.4 Advanced AMI Configuration
```
┌─────────────────────────────────────────┐
│         AMI Configuration               │
├─────────────────────────────────────────┤
│ AMI ID: ami-0c7217cdde317cfec          │
│ Instance Type: t3.small                 │
│ Subnet ID: subnet-xxxxx (optional)      │
│ Security Groups: sg-xxxxx (Jenkins-SG)  │
│ IAM Instance Profile: JenkinsAgentRole  │
│                                        │
│ Init Script:                           │
│ #!/bin/bash                            │
│ sudo apt update                        │
│ sudo apt install -y docker.io          │
│ sudo usermod -aG docker ubuntu          │
│ sudo systemctl start docker             │
└─────────────────────────────────────────┘
```

### 4.5 Configure Security Group for Agents
| Type | Protocol | Port | Source |
|------|----------|------|--------|
| SSH | TCP | 22 | Jenkins Master Security Group |
| Custom TCP | TCP | 50000 | Jenkins Master Security Group |

---

## Step 5: Configure Auto-Scaling

### 5.1 Enable Node Monitoring
1. Go to **Manage Jenkins** → **Configure System**
2. Set **# of executors** on master to **0** (security best practice)
3. All builds will run on dynamic EC2 agents

### 5.2 Configure Build Queue Monitoring
```groovy
// Add to Jenkinsfile for better resource utilization
pipeline {
    agent {
        label 'ubuntu-agent'
    }
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 30, unit: 'MINUTES')
    }
    stages {
        stage('Build') {
            steps {
                echo 'Building on dynamic EC2 agent...'
                sh 'echo "Agent: $(hostname)"'
                sh 'docker --version'
            }
        }
    }
}
```

### 5.3 Set Up CloudWatch Alarms (Optional)
```bash
# Create CloudWatch alarm for queue depth
aws cloudwatch put-metric-alarm \
    --alarm-name JenkinsQueueDepth \
    --alarm-description "Jenkins build queue depth" \
    --metric-name JenkinsQueueSize \
    --namespace Jenkins \
    --statistic Average \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2
```

---

## Step 6: Advanced Configuration

### 6.1 Spot Instance Integration
To reduce costs, use Spot Instances:

| Setting | Value |
|---------|-------|
| **Use Spot Instance** | ✓ Checked |
| **Spot Max Bid Price** | 0.05 (adjust based on region) |

### 6.2 Multiple Agent Templates
Create templates for different workloads:

| Template | Instance Type | Labels | Purpose |
|----------|---------------|--------|---------|
| Light Agent | t3.small | `light`, `quick` | Fast builds |
| Heavy Agent | t3.large | `heavy`, `docker` | Docker builds |
| GPU Agent | g4dn.xlarge | `gpu`, `ml` | Machine learning |

### 6.3 Pre-configured AMI (Recommended)
Instead of using init scripts, create a custom AMI:

```bash
# Launch base instance
# Install all required tools
sudo apt install -y docker.io git maven nodejs npm python3

# Create AMI
aws ec2 create-image \
    --instance-id i-xxxxxxxxx \
    --name "jenkins-agent-preconfigured" \
    --description "Jenkins agent with all tools"
```

---

## Step 7: Test Configuration

### 7.1 Test Agent Connection
1. Create a test job: **New Item** → **Freestyle project**
2. In **Restrict where this project can be run**, enter: `ubuntu-agent`
3. Add build step: **Execute shell**:
```bash
#!/bin/bash
echo "Running on: $(hostname)"
echo "OS: $(uname -a)"
docker --version || echo "Docker not installed"
```
4. Click **Build Now**

### 7.2 Verify Agent Creation
Check in AWS Console:
1. Navigate to **EC2** → **Instances**
2. You should see a new instance launching
3. Instance name will have prefix matching your template description

### 7.3 Check Jenkins Logs
```bash
# On Jenkins master
sudo tail -f /var/log/jenkins/jenkins.log
```

---

