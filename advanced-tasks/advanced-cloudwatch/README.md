# Advanced CloudWatch

Custom metrics, log-based metric filters, dashboard, and alerts for error rate > 5%.

## 1. Custom Metrics

**Console:** CloudWatch → Metrics → All metrics → Create custom metric
- Namespace: `MyApp`
- Metric name: `OrdersPerMinute`
- Value: 42

```

## 2. Log-Based Metric Filters

**Console:** CloudWatch → Log groups → `/aws/ec2/app` → Metric filters → Create
- Pattern: `[date, time, level=ERROR, ...]`
- Metric name: `Errors`
- Namespace: `MyApp`
- Value: 1

## 3. Dashboard

**Console:** CloudWatch → Dashboards → Create dashboard
- Name: `main`
- Add widgets:
  - Line: CPUUtilization (EC2)
  - Number: Errors (Custom)

## 4. Alert on Error Rate > 5%

**Console:** CloudWatch → Alarms → Create alarm
- Select metric: `MyApp/Errors`
- Metric math: `(errors / total) * 100`
- Threshold: > 5%
- Period: 5 minutes
- Evaluation periods: 2
