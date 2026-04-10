# Disaster Recovery

S3 cross-region replication, RDS read replicas, and AMI backups.

## 1. S3 Cross-Region Replication

**Console:** S3 → Create bucket
- Name: `my-data`
- Region: us-east-1
- Enable: Versioning

**Console:** S3 → Create bucket
- Name: `my-data-dr`
- Region: us-west-2
- Enable: Versioning

**Console:** S3 → `my-data` → Management → Replication rules → Create
- Destination: `my-data-dr`
- IAM role: Create new (S3ReplicationRole)

## 2. RDS Read Replica

**Console:** RDS → Databases → `my-db` → Actions → Create read replica
- DB identifier: `my-db-replica`
- Region: us-west-2
- Instance: db.t3.micro

**During failover:**
**Console:** RDS → Databases → `my-db-replica` → Actions → Promote

## 3. AMI Backup

**Console:** EC2 → Instances → Select → Actions → Image and templates → Create image
- Name: `backup-<date>`

**Console:** EC2 → AMIs → Select → Actions → Copy AMI
- Destination: us-west-2

## RPO/RTO

| Component | RPO | RTO |
|-----------|-----|-----|
| S3 | 15 min | 0 |
| RDS | 5 min | 10 min |
| EC2 | 24 hrs | 20 min |

## Cleanup

**Console:** S3 → Empty and delete buckets
**Console:** RDS → Delete replica
**Console:** EC2 → AMIs → Deregister
