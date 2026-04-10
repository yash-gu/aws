# EBS Storage

Create files, take snapshots, create volumes, attach, and verify data.

## 1. Create Files in EC2

```bash
ssh -i my-key.pem ec2-user@<INSTANCE_IP>

# Create test files
sudo mkdir -p /data/{documents,logs}
echo "config data" | sudo tee /data/config.txt
sudo dd if=/dev/urandom of=/data/large-file.dat bs=1M count=100

# Verify
sudo find /data -type f | wc -l
sudo du -sh /data
```

## 2. Create Snapshot

```bash
# Create snapshot
SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --volume-id vol-xxxxxxxxxxxxx \
    --description "Backup $(date +%Y-%m-%d)" \
    --query 'SnapshotId' --output text)

# Wait for completion
aws ec2 wait snapshot-completed --snapshot-ids $SNAPSHOT_ID
```

## 3. Create Volume from Snapshot

```bash
VOLUME_ID=$(aws ec2 create-volume \
    --snapshot-id $SNAPSHOT_ID \
    --volume-type gp3 \
    --size 20 \
    --availability-zone us-east-1a \
    --query 'VolumeId' --output text)

aws ec2 wait volume-available --volume-ids $VOLUME_ID
```

## 4. Attach Volume

```bash
# Attach to instance
aws ec2 attach-volume \
    --volume-id $VOLUME_ID \
    --instance-id i-xxxxxxxxxxxxx \
    --device /dev/xvdf

# Mount on instance
sudo mkdir -p /mnt/restored-data
sudo mount /dev/xvdf /mnt/restored-data
df -h
```

## 5. Verify Data

```bash
# Check files
ls -laR /mnt/restored-data
du -sh /mnt/restored-data

# Persistent mount
sudo blkid /dev/xvdf
echo "UUID=$(sudo blkid -s UUID -o value /dev/xvdf) /mnt/restored-data ext4 defaults,noatime 0 0" | sudo tee -a /etc/fstab
```

## Cleanup

```bash
aws ec2 detach-volume --volume-id $VOLUME_ID
aws ec2 delete-volume --volume-id $VOLUME_ID
aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
