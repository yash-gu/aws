aws ec2 create-route-table --vpc-id <VPC_ID>

aws ec2 create-route \
  --route-table-id <PUBLIC_RT_ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id <IGW_ID>


  aws ec2 create-route \
  --route-table-id <PRIVATE_RT_ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <NAT_ID>