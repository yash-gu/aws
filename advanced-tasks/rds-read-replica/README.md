# RDS Read Replica

Create read replica, separate read/write traffic, and simulate load.

## 1. Create Primary DB
RDS → Create database
- Engine: MySQL
- Template: Free tier
- DB instance identifier: `primary-db`
- Instance class: db.t3.micro
- Master username: admin
- Master password: (auto-generate)
- Allocated storage: 20 GB

## 2. Create Read Replica
RDS → Databases → `primary-db` → Actions → Create read replica
- DB instance identifier: `primary-db-replica`
- Same region or different region
- Instance class: db.t3.micro

## 3. Verify Replication
RDS → Databases → `primary-db-replica`
- Check Replica lag in Monitoring tab
- Connect and test: read works, write fails

## 4. Simulate Load

```bash
# Heavy reads on replica
for i in {1..100}; do
    mysql -h <replica-endpoint> -u admin -p -e "SELECT SLEEP(0.1)" &
done
wait
```

## 5. Promote to Standalone
RDS → Databases → `primary-db-replica` → Actions → Promote
- Disable replication
- Become standalone instance

