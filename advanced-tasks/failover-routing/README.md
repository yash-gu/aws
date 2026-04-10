# Failover Routing

Route 53 failover routing between primary and secondary ALBs with health checks.

## 1. Create Health Checks

**Console:** Route 53 → Health checks → Create health check
- Domain name: `primary-alb-xxxx.us-east-1.elb.amazonaws.com`
- Protocol: HTTP
- Port: 80
- Path: `/health`
- Request interval: 30 sec
- Failure threshold: 3

**Console:** Route 53 → Health checks → Create health check
- Domain name: `secondary-alb-xxxx.us-west-2.elb.amazonaws.com`
- Same settings

## 2. Create Failover Records

**Console:** Route 53 → Hosted zones → Select zone → Create record
- Name: `app.example.com`
- Type: A
- Routing policy: Failover
- Failover record type: Primary
- Alias to ALB: Primary ALB (us-east-1)
- Health check: Primary health check
- Evaluate target health: Yes

**Console:** Route 53 → Hosted zones → Select zone → Create record
- Name: `app.example.com`
- Type: A
- Routing policy: Failover
- Failover record type: Secondary
- Alias to ALB: Secondary ALB (us-west-2)
- Health check: Secondary health check
- Evaluate target health: Yes

## 3. Test Failover

```bash
# Check current DNS
dig app.example.com +short

# Wait ~90s after stopping primary, verify DNS switches
```

**Console:** Route 53 → Health checks → View status

## Cleanup

**Console:** Route 53 → Hosted zones → Select records → Delete
**Console:** Route 53 → Health checks → Select → Delete
