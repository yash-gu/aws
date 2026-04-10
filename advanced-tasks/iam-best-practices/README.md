# IAM Best Practices

Quick setup for IAM groups, MFA, and least privilege policies.

## 1. Enable MFA for Root

1.png

## 2. Create Groups

**Console:** IAM → User groups → Create group
- Name: `Admins`
- Attach policy: AdministratorAccess


- Name: `Developers`
- Attach policy: PowerUserAccess
![alt text](<Screenshot 2026-04-10 at 9.30.05 AM.png>)

- Name: `ReadOnly`
- Attach policy: ReadOnlyAccess
![alt text](image.png)


![alt text](image-1.png)

## 3. Custom S3 Restricted Policy

**Console:** IAM → Policies → Create policy → JSON

![alt text](image-2.png)
- Name: `S3RestrictedAccess`
![alt text](image-3.png)

## 4. Create Users

![alt text](image-4.png)

## 5. Password Policy

![alt text](image-5.png)

