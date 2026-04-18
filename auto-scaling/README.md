"""# AWS Auto Scaling Group (ASG) Setup Guide (Console Only)

This guide covers the essential steps to create a self-healing, auto-scaling architecture using the AWS Management Console.

---

## Phase 1: Create the Golden Image (AMI)
Before the ASG can launch instances, it needs a pre-configured image of your server.

1. Launch a single EC2 instance and install your application (e.g., Nginx, Node.js).
2. Ensure your application is configured to start automatically on boot (using `systemctl enable`).
3.  **Create Image:**
    * Go to **EC2 Console** > **Instances** > Select your instance.
    * Click **Actions** > **Image and templates** > **Create image**.
    * **Image name:** `webapp-golden-image`.
    * Click **Create image**.
4.  **Wait:** Navigate to **AMIs** in the left sidebar. Wait until the status is **Available**.

---

## Phase 2: Create the Launch Template
The Launch Template defines the "specs" for every new instance the ASG creates.

1.  **Navigate:** Go to **EC2 Console** > **Launch Templates** > **Create launch template**.
2.  **Basic Settings:**
    * **Name:** `webapp-launch-template`.
    * **Auto Scaling guidance:** Check the box.
3.  **Application and OS Images:** Select **My AMIs** and choose your `webapp-golden-image`.
4.  **Instance Type:** Select `t2.micro` (or your preferred type).
5.  **Network Settings:**
    * **Security Groups:** Select the group that allows traffic from your **ALB**.
6.  **Advanced Details (User Data):** * Scroll to the bottom and paste this script to ensure the service is running:
    ```

[file-tag: code-generated-file-0-1776508506844579225]
bash
    #!/bin/bash
    sudo systemctl start nginx
    ```
7.  Click **Create launch template**.

---

## Phase 3: Create the Auto Scaling Group
The ASG manages the fleet of instances and responds to load or failures.

1.  **Navigate:** Go to **EC2 Console** > **Auto Scaling Groups** > **Create Auto Scaling group**.
2.  **Step 1 (Choose Template):** Name it `webapp-asg` and select your `webapp-launch-template`.
3.  **Step 2 (Network):** * Select your **VPC**.
    * **Subnets:** Select at least **two** public subnets in different Availability Zones (e.g., `us-east-1a` and `us-east-1b`).
4.  **Step 3 (Advanced Options):**
    * **Load Balancing:** Select **Attach to an existing load balancer**.
    * Select your **Target Group**.
    * **Health checks:** Check the box for **ELB** health checks.
    * **Health check grace period:** Set to `300` seconds.
5.  **Step 4 (Group Size):**
    * **Desired capacity:** `2`.
    * **Minimum capacity:** `2`.
    * **Maximum capacity:** `5`.
6.  **Step 5 (Scaling Policy):**
    * Select **Target tracking scaling policy**.
    * **Metric type:** `Average CPU utilization`.
    * **Target value:** `50`.
7.  **Review and Create:** Click **Create Auto Scaling group**.

---

## Phase 4: Verification
1.  **Check Instances:** Go to **EC2 Instances**. You should see 2 new instances starting up automatically.
2.  **The "Terminator" Test:** Terminate one of these instances manually.
3.  **Result:** Within a few minutes, the ASG should detect the failure and launch a replacement instance to maintain the desired count of 2.

---

## Compulsory Configuration Summary
| Setting | Selection | Importance |
| :--- | :--- | :--- |
| **Health Check** | **ELB** | Replaces instances if the application (not just the VM) stops responding. |
| **Availability Zones** | **2 or more** | Ensures your site stays up even if an entire AWS data center goes down. |
| **Desired Capacity** | **Minimum 2** | Necessary to verify that the Load Balancer is distributing traffic correctly. |
"""