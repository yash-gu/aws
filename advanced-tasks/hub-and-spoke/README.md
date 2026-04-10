# Hub-and-Spoke VPC

Hub VPC (10.0.0.0/16) + 2 Spoke VPCs with peering. Spokes only talk to Hub, not each other.

## 1. Create VPCs

**Console:** VPC → Create VPC
- Name: `Hub`
- CIDR: 10.0.0.0/16

**Console:** VPC → Create VPC
- Name: `Spoke-A-Dev`
- CIDR: 10.1.0.0/16

**Console:** VPC → Create VPC
- Name: `Spoke-B-Prod`
- CIDR: 10.2.0.0/16

## 2. Create Peering Connections

**Console:** VPC → Peering connections → Create
- Name: `Hub-to-Spoke-A`
- VPC (Requester): Hub
- VPC (Accepter): Spoke-A-Dev
- Accept the peering

**Console:** VPC → Peering connections → Create
- Name: `Hub-to-Spoke-B`
- VPC (Requester): Hub
- VPC (Accepter): Spoke-B-Prod
- Accept the peering

## 3. Configure Routes

**Console:** VPC → Route tables → Hub main RT → Routes → Edit
- Destination: 10.1.0.0/16 → Peering connection (Hub-to-Spoke-A)
- Destination: 10.2.0.0/16 → Peering connection (Hub-to-Spoke-B)

**Console:** VPC → Route tables → Spoke-A RT → Routes → Edit
- Destination: 10.0.0.0/16 → Peering connection (Hub-to-Spoke-A)

**Console:** VPC → Route tables → Spoke-B RT → Routes → Edit
- Destination: 10.0.0.0/16 → Peering connection (Hub-to-Spoke-B)

## 4. Security Groups

**Console:** EC2 → Security groups → Create (Hub)
- Name: `hub-sg`
- Inbound: All traffic from 10.1.0.0/16, 10.2.0.0/16

**Console:** EC2 → Security groups → Create (Spoke-A)
- Name: `spoke-a-sg`
- Inbound: All traffic from 10.0.0.0/16

**Console:** EC2 → Security groups → Create (Spoke-B)
- Name: `spoke-b-sg`
- Inbound: All traffic from 10.0.0.0/16

## 5. Test Instances

**Console:** EC2 → Launch instances in each VPC
- Hub: t2.micro, `hub-sg`, Hub subnet
- Spoke-A: t2.micro, `spoke-a-sg`, Spoke-A subnet
- Spoke-B: t2.micro, `spoke-b-sg`, Spoke-B subnet

## 6. Test Connectivity

- From Spoke-A: ping Hub (works)
- From Spoke-A: ping Spoke-B (fails - no route by design)
- From Hub: ping both spokes (works)

## Cleanup

**Console:** EC2 → Terminate all instances
**Console:** VPC → Peering connections → Delete
**Console:** EC2 → Security groups → Delete
**Console:** VPC → Delete VPCs
