# AWS Application Load Balancer (ALB) Setup Guide (Console Only)

This guide outlines the essential, compulsory steps to set up an Application Load Balancer using the AWS Management Console.

---

## Phase 1: Create the Target Group
The Target Group defines where the traffic will be directed (your backend instances).

1.  **Navigate:** Go to **EC2 Console** > **Target Groups** > **Create target group**.
2.  **Basic Configuration:**
    * **Target type:** Select **Instances**.
    * **Target group name:** `my-app-tg`.
    * **Protocol:** `HTTP`.
    * **Port:** `80` (or the specific port your application is listening on, e.g., `3000`).
    * **VPC:** Select your project VPC.
3.  **Health Checks:**
    * **Health check path:** `/` (Ensure your application returns a `200 OK` at this path).
4.  **Register Targets:**
    * Select your running EC2 instances from the list.
    * Click **Include as pending below**.
    * Click **Create target group**.

---

## Phase 2: Create the Application Load Balancer
The ALB acts as the entry point for your traffic.

1.  **Navigate:** Go to **EC2 Console** > **Load Balancers** > **Create load balancer**.
2.  **Select Type:** Click **Create** under **Application Load Balancer**.
3.  **Basic Configuration:**
    * **Load balancer name:** `my-app-alb`.
    * **Scheme:** **Internet-facing**.
    * **IP address type:** `IPv4`.
4.  **Network Mapping:**
    * **VPC:** Select your project VPC.
    * **Mappings:** Select at least **two** Availability Zones and a **Public Subnet** for each.
5.  **Security Groups:**
    * Select a Security Group that allows **Inbound HTTP (80)** from `0.0.0.0/0`.
6.  **Listeners and Routing:**
    * **Protocol:** `HTTP` | **Port:** `80`.
    * **Default action:** Select the **Target Group** created in Phase 1 (`my-app-tg`).
7.  **Review and Create:** Click **Create load balancer**.

---

## Phase 3: Update Instance Security Group (Compulsory)
To ensure security, your EC2 instances should only accept traffic from the ALB, not the open internet.

1.  Go to **EC2 Console** > **Security Groups**.
2.  Select the **Security Group attached to your EC2 instances**.
3.  Go to the **Inbound rules** tab and click **Edit inbound rules**.
4.  **Update/Add Rule:**
    * **Type:** `HTTP`.
    * **Port range:** `80` (or your app port).
    * **Source:** Delete `0.0.0.0/0` and search for the **Security Group ID of your ALB** (e.g., `sg-xxxxxx`).
5.  Click **Save rules**.
