1. make a vpc in a particular region
- with ipv4 cidr : 10.0.0.0/16
- name : bastion-host
(images/2.png)
2. make 2 subnets in that vpc (public and private)
(images/3.png)
(images/4.png)
(images/5.png)

3. make interet gateway
(images/6.png)

4. connect the internet gateway to the public-subnet
(images/7.png)
(images/8.png)

5. make routing table for pub subnet
(images/9.png)
(images/10.png)


5. make a nat gateway for the public subnet 
(images/11.png)
(images/12.png)

6. using route table connect the nat to private subnet
(images/13.png)


and you have build it 