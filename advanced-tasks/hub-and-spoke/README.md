# Hub-and-Spoke VPC

Hub VPC (10.0.0.0/16) + 2 Spoke VPCs with peering. Spokes only talk to Hub, not each other.

## 1. Create VPCs

**Console:** VPC → Create VPC
- Name: `Hub`
- CIDR: 10.0.0.0/16
![alt text](image.png)

**Console:** VPC → Create VPC
- Name: `Spoke-A`
- CIDR: 10.1.0.0/16
![alt text](image-1.png)


**Console:** VPC → Create VPC
- Name: `Spoke-B`
- CIDR: 10.2.0.0/16
![alt text](image-2.png)

## 2. Create Peering Connections

**Console:** VPC → Peering connections → Create
- Name: `Hub-to-Spoke-A`
- VPC (Requester): Hub
- VPC (Accepter): Spoke-A
![alt text](image-3.png)
- Accept the peering
![alt text](image-4.png)

**Console:** VPC → Peering connections → Create
- Name: `Hub-to-Spoke-B`
- VPC (Requester): Hub
- VPC (Accepter): Spoke-B
![alt text](image-5.png)
- Accept the peering
![alt text](image-6.png)
## 3. Configure Routes

**Console:** VPC → Route tables → Hub main RT → Routes → Edit
- Destination: 10.1.0.0/16 → Peering connection (Hub-to-Spoke-A)
- Destination: 10.2.0.0/16 → Peering connection (Hub-to-Spoke-B)
![alt text](image-8.png)

**Console:** VPC → Route tables → Spoke-A RT → Routes → Edit
- Destination: 10.0.0.0/16 → Peering connection (Hub-to-Spoke-A)
![alt text](image-9.png)
**Console:** VPC → Route tables → Spoke-B RT → Routes → Edit
- Destination: 10.0.0.0/16 → Peering connection (Hub-to-Spoke-B)
![alt text](image-10.png)

## 4. Security Groups

**Console:** EC2 → Security groups → Create (Hub)
![alt text](image-11.png)

**Console:** EC2 → Security groups → Create (Spoke-A)
![alt text](image-12.png)

**Console:** EC2 → Security groups → Create (Spoke-B)
![alt text](image-13.png)

## 5. Test Instances

**Console:** EC2 → Launch instances in each VPC
- Hub: t2.micro, `hub-sg`, Hub subnet
![alt text](image-14.png)
- Spoke-A: t2.micro, `spoke-a-sg`, Spoke-A subnet
- Spoke-B: t2.micro, `spoke-b-sg`, Spoke-B subnet

## 6. Test Connectivity

- From Spoke-A: ping Hub (works)
- From Spoke-A: ping Spoke-B (fails - no route by design)
- From Hub: ping both spokes (works)



