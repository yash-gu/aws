# Path-Based Routing

Create target groups, launch instances, configure ALB path routing, and Route 53 DNS.

## 1. Create Target Groups

```bash
VIDEOS_TG_ARN=$(aws elbv2 create-target-group --name videos-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --health-check-path /health --query 'TargetGroups[0].TargetGroupArn' --output text)
IMAGES_TG_ARN=$(aws elbv2 create-target-group --name images-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --health-check-path /health --query 'TargetGroups[0].TargetGroupArn' --output text)
DEFAULT_TG_ARN=$(aws elbv2 create-target-group --name default-tg --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
```

## 2. Launch Instances

```bash
AMI_ID=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-*-x86_64' --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

# Video servers user data
cat > videos-user-data.sh << 'EOF'
#!/bin/bash
yum update -y && yum install -y nginx
systemctl start nginx && systemctl enable nginx
EOF

# Image servers user data
cat > images-user-data.sh << 'EOF'
#!/bin/bash
yum update -y && yum install -y nginx
systemctl start nginx && systemctl enable nginx
EOF

# Launch and register video servers
VIDEOS_SG=$(aws ec2 create-security-group --group-name videos-sg --description "Video servers" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $VIDEOS_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
VIDEO_INSTANCE_1=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --security-group-ids $VIDEOS_SG --subnet-id $PUBLIC_SUBNET_1 --associate-public-ip-address --user-data file://videos-user-data.sh --query 'Instances[0].InstanceId' --output text)
VIDEO_INSTANCE_2=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --security-group-ids $VIDEOS_SG --subnet-id $PUBLIC_SUBNET_2 --associate-public-ip-address --user-data file://videos-user-data.sh --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $VIDEO_INSTANCE_1 $VIDEO_INSTANCE_2
aws elbv2 register-targets --target-group-arn $VIDEOS_TG_ARN --targets Id=$VIDEO_INSTANCE_1 Id=$VIDEO_INSTANCE_2

# Launch and register image servers
IMAGES_SG=$(aws ec2 create-security-group --group-name images-sg --description "Image servers" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $IMAGES_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
IMAGE_INSTANCE_1=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --security-group-ids $IMAGES_SG --subnet-id $PUBLIC_SUBNET_1 --associate-public-ip-address --user-data file://images-user-data.sh --query 'Instances[0].InstanceId' --output text)
IMAGE_INSTANCE_2=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --security-group-ids $IMAGES_SG --subnet-id $PUBLIC_SUBNET_2 --associate-public-ip-address --user-data file://images-user-data.sh --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $IMAGE_INSTANCE_1 $IMAGE_INSTANCE_2
aws elbv2 register-targets --target-group-arn $IMAGES_TG_ARN --targets Id=$IMAGE_INSTANCE_1 Id=$IMAGE_INSTANCE_2
```

## 3. Create ALB and Path Rules

```bash
ALB_ARN=$(aws elbv2 create-load-balancer --name path-based-alb --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --security-groups $ALB_SG_ID --scheme internet-facing --type application --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

LISTENER_ARN=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$DEFAULT_TG_ARN --query 'Listeners[0].ListenerArn' --output text)

# Path rules
aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 1 --conditions '[{"Field":"path-pattern","PathPatternConfig":{"Values":["/videos/*","/videos"]}}]' --actions '[{"Type":"forward","TargetGroupArn":"'$VIDEOS_TG_ARN'"}]'
aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 2 --conditions '[{"Field":"path-pattern","PathPatternConfig":{"Values":["/images/*","/images"]}}]' --actions '[{"Type":"forward","TargetGroupArn":"'$IMAGES_TG_ARN'"}]'
```

## 4. Test

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)
curl http://$ALB_DNS/videos
curl http://$ALB_DNS/images
```

## 5. Route 53 DNS

```bash
HOSTED_ZONE_ID=$(aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s) --query 'HostedZone.Id' --output text)
ALB_HOSTED_ZONE=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "app.example.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "'$ALB_HOSTED_ZONE'",
        "DNSName": "'$ALB_DNS'",
        "EvaluateTargetHealth": true
      }
    }
  }]
}'
```

## Cleanup

```bash
aws elbv2 delete-rule --rule-arn <RULE_ARN>
aws elbv2 delete-listener --listener-arn $LISTENER_ARN
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-target-group --target-group-arn $VIDEOS_TG_ARN
aws elbv2 delete-target-group --target-group-arn $IMAGES_TG_ARN
aws elbv2 delete-target-group --target-group-arn $DEFAULT_TG_ARN
aws ec2 terminate-instances --instance-ids $VIDEO_INSTANCE_1 $VIDEO_INSTANCE_2 $IMAGE_INSTANCE_1 $IMAGE_INSTANCE_2
aws ec2 delete-security-group --group-id $VIDEOS_SG
aws ec2 delete-security-group --group-id $IMAGES_SG
```

---

