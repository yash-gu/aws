# Load Testing with stress and siege

## Overview
This guide covers generating load on AWS infrastructure using `stress` for CPU load testing and `siege` for HTTP load testing.

![Load Testing](https://docs.aws.amazon.com/images/autoscaling/ec2/userguide/images/as-basic-diagram.png)

## Prerequisites
- EC2 instances with Auto Scaling configured
- Web application running behind Load Balancer
- SSH access to instances
- siege and stress tools installed

---

## Step 1: Install Load Testing Tools

### 1.1 Install stress (CPU Load)

#### Amazon Linux 2023 / RHEL / CentOS:
```bash
# Enable EPEL repository first
sudo dnf install epel-release -y

# Install stress
sudo dnf install stress -y

# Verify installation
stress --version
```

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install stress -y

# Verify installation
stress --version
```

### 1.2 Install siege (HTTP Load)

#### Amazon Linux 2023:
```bash
# Download and compile from source
cd /tmp
wget http://download.joedog.org/siege/siege-latest.tar.gz
tar -xvf siege-latest.tar.gz
cd siege-*/
./configure
make
sudo make install

# Verify installation
siege --version
```

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install siege -y

# Verify installation
siege --version
```

#### Alternative: Use Docker
```bash
# Run siege without installing
docker run --rm rufus/siege -c 50 -t 1M http://your-target-url/
```

---

## Step 2: stress - CPU Load Testing

### 2.1 Basic stress Usage
```bash
# Generate CPU load with 4 workers for 600 seconds (10 minutes)
stress --cpu 4 --timeout 600

# Parameters:
# --cpu 4     = 4 CPU workers
# --timeout 600 = run for 600 seconds
```

### 2.2 stress Options Reference

| Option | Description | Example |
|--------|-------------|---------|
| `--cpu N` | Spawn N workers spinning on sqrt() | `--cpu 4` |
| `--io N` | Spawn N workers spinning on sync() | `--io 2` |
| `--vm N` | Spawn N workers spinning on malloc()/free() | `--vm 2` |
| `--vm-bytes B` | Allocate B bytes per VM worker | `--vm-bytes 128M` |
| `--timeout T` | Timeout after T seconds | `--timeout 60s` |
| `--hdd N` | Spawn N workers spinning on write()/unlink() | `--hdd 1` |

### 2.3 Common stress Commands

```bash
# Light CPU load (2 cores, 5 minutes)
stress --cpu 2 --timeout 300

# Heavy CPU load (all cores, 10 minutes)
stress --cpu $(nproc) --timeout 600

# Combined CPU + Memory load
stress --cpu 4 --vm 2 --vm-bytes 256M --timeout 600

# CPU + I/O load
stress --cpu 4 --io 2 --timeout 300

# Full system stress test
stress --cpu 4 --io 2 --vm 2 --hdd 1 --timeout 600
```

### 2.4 Monitor stress in Real-time
```bash
# Terminal 1: Run stress
stress --cpu 4 --timeout 600

# Terminal 2: Monitor CPU usage
watch -n 1 "top -bn1 | head -20"

# Or use htop (if installed)
htop
```

---

## Step 3: siege - HTTP Load Testing

### 3.1 Basic siege Usage
```bash
# 100 concurrent connections for 5 minutes
siege -c 100 -t 5M http://your-alb-dns-name/

# Parameters:
# -c 100 = 100 concurrent users
# -t 5M  = run for 5 Minutes
```

### 3.2 siege Options Reference

| Option | Description | Example |
|--------|-------------|---------|
| `-c N` | Concurrent connections | `-c 100` |
| `-t TIME` | Time to run (S=seconds, M=minutes, H=hours) | `-t 10M` |
| `-r N` | Number of repetitions | `-r 1000` |
| `-f FILE` | URLs from file | `-f urls.txt` |
| `-i` | Internet mode (random URLs) | `-i` |
| `-b` | Benchmark mode (no delays) | `-b` |
| `-H HEADER` | Custom header | `-H "Authorization: Bearer token"` |
| `-T CONTENT-TYPE` | Content-Type header | `-T "application/json"` |

### 3.3 Common siege Commands

```bash
# Basic load test (50 concurrent, 2 minutes)
siege -c 50 -t 2M http://webapp-alb-xxx.us-east-1.elb.amazonaws.com/

# Heavy load test (200 concurrent, 10 minutes)
siege -c 200 -t 10M http://webapp-alb-xxx.us-east-1.elb.amazonaws.com/

# Benchmark mode (maximum speed)
siege -c 100 -t 1M -b http://your-site.com/

# Load test with multiple URLs
cat > urls.txt << 'EOF'
http://your-site.com/
http://your-site.com/about
http://your-site.com/api/data
EOF
siege -c 50 -t 5M -f urls.txt

# Random URL selection (internet mode)
siege -c 50 -t 5M -i -f urls.txt
```

### 3.4 Interpreting siege Results

```
Lifting the server siege...
Transactions:                  10000 hits          # Total requests completed
Availability:                 100.00 %             # Success rate
Elapsed time:                 299.58 secs          # Total test duration
Data transferred:              24.41 MB             # Total data transferred
Response time:                  1.50 secs           # Average response time
Transaction rate:              33.38 trans/sec      # Requests per second
Throughput:                     0.08 MB/sec         # Data transfer rate
Concurrency:                   49.89                # Average concurrent users
Successful transactions:       10000                # 200 OK responses
Failed transactions:             0                 # Failed requests
Longest transaction:           3.50 secs            # Slowest request
Shortest transaction:          0.10 secs            # Fastest request
```

---

## Step 4: Auto Scaling Trigger Testing

### 4.1 Test CPU-Based Scaling
```bash
# SSH to one of the ASG instances
ssh -i my-key.pem ec2-user@<INSTANCE_IP>

# Generate CPU load to trigger scale-out
stress --cpu 4 --timeout 600 &

# Monitor in AWS Console:
# EC2 → Auto Scaling Groups → webapp-asg → Activity
```

### 4.2 Test Request-Based Scaling
```bash
# From your local machine or another EC2
siege -c 200 -t 10M http://your-alb-dns.amazonaws.com/

# Monitor CloudWatch metrics:
# RequestCountPerTarget, CPUUtilization
```

### 4.3 Monitor Scaling Events
```bash
# Watch scaling activities
aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name webapp-asg \
    --max-items 10

# Watch CloudWatch metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=webapp-asg \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-01T01:00:00Z \
    --period 300 \
    --statistics Average
```

---

## Step 5: Advanced Load Testing Scenarios

### 5.1 Ramp-Up Testing
```bash
#!/bin/bash
# ramp_test.sh - Gradually increase load

for concurrency in 10 25 50 75 100 150 200; do
    echo "Testing with $concurrency concurrent users..."
    siege -c $concurrency -t 2M -b http://your-site.com/ 2>&1 | tail -10
    sleep 30
done
```

### 5.2 Spike Testing
```bash
# Sudden spike in traffic
siege -c 10 -t 1M http://your-site.com/ &  # Baseline
sleep 30
siege -c 500 -t 30S http://your-site.com/   # Spike
```

### 5.3 Endurance Testing
```bash
# Sustained load for extended period
siege -c 100 -t 60M http://your-site.com/  # 1 hour
```

### 5.4 Simultaneous CPU + HTTP Load
```bash
# Terminal 1: HTTP load
siege -c 100 -t 10M http://your-site.com/

# Terminal 2 (on EC2): CPU load
stress --cpu 4 --timeout 600
```

---

## Step 6: Monitoring During Load Tests

### 6.1 CloudWatch Metrics to Watch
| Metric | Namespace | Threshold |
|--------|-----------|-----------|
| CPUUtilization | AWS/EC2 | Scale up > 70% |
| RequestCountPerTarget | AWS/ApplicationELB | - |
| TargetResponseTime | AWS/ApplicationELB | Alert > 2s |
| HealthyHostCount | AWS/ApplicationELB | Alert < Min |
| UnHealthyHostCount | AWS/ApplicationELB | Alert > 0 |

### 6.2 Real-time Monitoring Commands
```bash
# Watch Auto Scaling activities in real-time
watch -n 5 'aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name webapp-asg --output table'

# Watch instance count
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names webapp-asg \
    --query "AutoScalingGroups[0].Instances" --output table'

# Monitor ALB target health
watch -n 5 'aws elbv2 describe-target-health \
    --target-group-arn <TARGET_GROUP_ARN> --output table'
```

### 6.3 Create CloudWatch Dashboard
```bash
# Create dashboard for load testing
aws cloudwatch put-dashboard \
    --dashboard-name LoadTest-Monitoring \
    --dashboard-body file://dashboard.json
```

---

## Step 7: Load Testing Best Practices

### 7.1 Before Testing
- [ ] Notify team about testing window
- [ ] Verify Auto Scaling limits are appropriate
- [ ] Ensure monitoring is active
- [ ] Have rollback plan ready

### 7.2 During Testing
- [ ] Monitor metrics continuously
- [ ] Watch for error rates
- [ ] Document any anomalies
- [ ] Stay within budget limits

### 7.3 After Testing
- [ ] Stop all load generators
- [ ] Allow scale-in to complete
- [ ] Review results and metrics
- [ ] Document findings

---

## Troubleshooting

### Issue: stress command not found
```bash
# Install from source if package not available
cd /tmp
git clone https://github.com/resurrecting-open-source-projects/stress.git
cd stress/
./autogen.sh
./configure
make
sudo make install
```

### Issue: siege connection refused
```bash
# Check:
1. Target URL is correct and accessible
2. Security groups allow traffic
3. Load balancer is healthy
4. Not hitting rate limits

# Test connectivity first
curl -I http://your-target-url/
```

### Issue: Too many open files
```bash
# Increase file descriptor limits
ulimit -n 65535

# Or run siege with limits
sudo sh -c 'ulimit -n 65535 && siege -c 1000 -t 1M http://site.com/'
```

---

## Command Quick Reference

### stress Commands
```bash
stress --cpu 4 --timeout 600          # 4 CPU, 10 minutes
stress --cpu $(nproc) --timeout 300   # All cores, 5 minutes
stress --vm 2 --vm-bytes 512M -t 300   # Memory stress
stress --cpu 2 --io 1 -t 300          # CPU + I/O
```

### siege Commands
```bash
siege -c 50 -t 5M http://site.com/    # 50 concurrent, 5 min
siege -c 200 -t 10M http://site.com/  # Heavy load
siege -c 100 -t 1M -b http://site.com/ # Benchmark mode
siege -c 50 -f urls.txt -i             # Random URLs
```

---

## Sample Testing Plan

| Phase | Duration | Load | Purpose |
|-------|----------|------|---------|
| Warm-up | 2 min | 10 users | Establish baseline |
| Ramp-up | 5 min | 10→100 users | Find breaking point |
| Steady | 10 min | 100 users | Sustained load test |
| Spike | 2 min | 500 users | Test scale-out speed |
| Recovery | 10 min | 10 users | Test scale-in |

---

**References:**
- [siege Official Documentation](https://www.joedog.org/siege-manual/)
- [stress Manual](https://linux.die.net/man/1/stress)
- [AWS Auto Scaling Testing](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-test-scaleout.html)
