# AWS Bastion Host Setup


A bastion host in AWS is a specialized EC2 instance that serves as a secure gateway for accessing private resources in a VPC, such as backend servers or databases, without exposing them directly to the internet. It typically resides in a public subnet with a public IP, allowing SSH (port 22) connections only from trusted IPs, then "jumps" to private instances in private subnets.


![AWS VPC diagram](images/1.png)