aws ec2 create-security-group \
  --group-name web-sg \
  --description "Allow HTTP" \
  --vpc-id <VPC_ID>


aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0