aws ec2 allocate-address --domain vpc

aws ec2 create-nat-gateway \
  --subnet-id <PUBLIC_SUBNET_ID> \
  --allocation-id <EIP_ALLOCATION_ID>