# IAM Best Practices

Quick setup for IAM groups, MFA, and least privilege policies.

## 1. Enable MFA for Root

**Console:** IAM → Dashboard → Add MFA → Activate MFA (use Google Authenticator)

## 2. Create Groups

**Console:** IAM → User groups → Create group
- Name: `Admins`
- Attach policy: AdministratorAccess

**Console:** IAM → User groups → Create group
- Name: `Developers`
- Attach policy: PowerUserAccess

**Console:** IAM → User groups → Create group
- Name: `ReadOnly`
- Attach policy: ReadOnlyAccess

## 3. Custom S3 Restricted Policy

**Console:** IAM → Policies → Create policy → JSON
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*",
            "Condition": {
                "StringNotEquals": {
                    "s3:ResourceAccount": "123456789012"
                }
            }
        },
        {
            "Effect": "Deny",
            "Action": "s3:DeleteBucket",
            "Resource": "*"
        }
    ]
}
```
- Name: `S3RestrictedAccess`

## 4. Create Users

**Console:** IAM → Users → Add users
- User name: `john-dev`
- Credentials: Console password + Access key
- Groups: `Developers`

## 5. Password Policy

**Console:** IAM → Account settings → Password policy → Edit
- Minimum length: 12
- Require symbols, numbers, uppercase, lowercase
- Password expiration: 90 days
- Prevent reuse: 5 passwords

## Cleanup

**Console:** IAM → Users → `john-dev` → Delete
**Console:** IAM → User groups → Select group → Delete
**Console:** IAM → Policies → `S3RestrictedAccess` → Delete
