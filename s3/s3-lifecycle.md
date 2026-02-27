# S3 Lifecycle Rule Configuration Guide

This document explains how to create an Amazon S3 lifecycle rule to automatically transition and expire objects stored under a specific prefix.

---

## 📌 Lifecycle Policy Overview

This lifecycle rule applies **only to objects inside the `uploads/` folder** and performs the following actions:

| After  | Action                          |
|--------|----------------------------------|
| 30 days | Transition to Standard-IA       |
| 90 days | Transition to Glacier           |
| 365 days | Permanently delete the object |

---

## 🛠 Step-by-Step Setup Guide

### 1️⃣ Navigate to Your S3 Bucket

- Log in to the **AWS Management Console**
- Open the **S3** service
- Select your target bucket

---

### 2️⃣ Open the Management Tab

Inside your bucket:

- Click on the **Management** tab
- Select **Create lifecycle rule**

![Create Lifecycle Rule](image/1.png)

---

### 3️⃣ Configure Lifecycle Rule

#### Rule Settings

- **Rule name:** `UploadsLifecycleRule`
- **Rule scope:** Limit the scope using a prefix
- **Prefix value:** `uploads/`

---

### 4️⃣ Configure Lifecycle Actions

Add the following transitions:

- Transition after **30 days** → Standard-IA  
- Transition after **90 days** → Glacier  

Then configure expiration:

- Expire objects after **365 days**

![Lifecycle Configuration Step](image/2.png)

---

### 5️⃣ Review and Create

- Review the configuration
- Click **Create rule**

![Review and Create Rule](image/3.png)
