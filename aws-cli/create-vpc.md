aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16


aws ec2 modify-vpc-attribute --vpc-id <VPC_ID> --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id <VPC_ID> --enable-dns-hostnames