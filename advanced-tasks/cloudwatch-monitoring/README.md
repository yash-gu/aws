# CloudWatch Monitoring

Basic CloudWatch setup for EC2, ALB, and alarms.

## 1. Enable Detailed Monitoring

**Console:** EC2 → Instances → Select → Actions → Monitor and troubleshoot → Manage detailed monitoring → Enable

## 2. Create SNS Topic for Alerts

**Console:** SNS → Topics → Create topic
- Name: `alerts`
- Type: Standard

**Console:** SNS → Topics → `alerts` → Create subscription
- Protocol: Email
- Endpoint: admin@example.com

## 3. Create CPU Alarm

**Console:** CloudWatch → Alarms → Create alarm
- Select metric: EC2 → `CPUUtilization`
- Threshold: > 80%
- Period: 5 minutes
- Evaluation: 2 periods
- Action: SNS topic `alerts`

## 4. ALB Alarms

**Console:** CloudWatch → Alarms → Create alarm
- Select metric: ApplicationELB → `TargetResponseTime`
- Alarm name: `alb-latency`
- Threshold: > 2 seconds

**Console:** CloudWatch → Alarms → Create alarm
- Select metric: ApplicationELB → `HTTPCode_ELB_5XX_Count`
- Alarm name: `alb-5xx`
- Threshold: >= 1

## 5. Dashboard

**Console:** CloudWatch → Dashboards → Create dashboard
- Name: `main`
- Add widgets:
  - EC2 CPU utilization
  - ALB request count
  - ALB 5xx errors

## 6. CloudWatch Agent (Memory/Disk)

**CLI:** Install and configure
```bash
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U amazon-cloudwatch-agent.rpm
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-linux
```

## Cleanup

**Console:** CloudWatch → Alarms → Select all → Delete
**Console:** SNS → Topics → `alerts` → Delete
