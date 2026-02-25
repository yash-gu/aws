AWS IAM Policy Practice Tasks
=============================


This file contains IAM policy examples demonstrating permission control using Allow, Deny, and Conditions in AWS.


----------------------------------------------------------------------
Task 1 – EC2: Allow All Actions BUT Deny Termination
----------------------------------------------------------------------


Description:
- Allows all EC2 actions
- Explicitly denies terminating instances


Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAllEC2",
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    },
    {
      "Sid": "DenyTerminate",
      "Effect": "Deny",
      "Action": "ec2:TerminateInstances",
      "Resource": "*"
    }
  ]
}


----------------------------------------------------------------------
Task 2 – S3: Allow Full Access BUT Deny One Specific Bucket
----------------------------------------------------------------------


Description:
- Full access to all S3 buckets
- Denies access to a specific bucket


Replace 'restricted-bucket-name' with the target bucket name.


Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAllS3",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Sid": "DenySpecificBucket",
      "Effect": "Deny",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::restricted-bucket-name",
        "arn:aws:s3:::restricted-bucket-name/*"
      ]
    }
  ]
}


----------------------------------------------------------------------
Task 3 – EC2: Allow Start/Stop BUT Deny in Specific Region
----------------------------------------------------------------------


Description:
- Allows StartInstances and StopInstances
- Denies Start/Stop in 'us-east-1' region


Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowStartStop",
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyInRegion",
      "Effect": "Deny",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}


----------------------------------------------------------------------
Task 4 – VPC: Allow VPC Creation BUT Deny Internet Gateway Creation
----------------------------------------------------------------------


Description:
- Allows creation of VPC
- Denies creation of Internet Gateway


Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowVPCCreation",
      "Effect": "Allow",
      "Action": "ec2:CreateVpc",
      "Resource": "*"
    },
    {
      "Sid": "DenyInternetGateway",
      "Effect": "Deny",
      "Action": "ec2:CreateInternetGateway",
      "Resource": "*"
    }
  ]
}


----------------------------------------------------------------------
Task 5 – S3: Deny Deletion BUT Allow Everything Else
----------------------------------------------------------------------


Description:
- Allows all S3 actions except deletion


Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAllS3",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Sid": "DenyDelete",
      "Effect": "Deny",
      "Action": [
        "s3:DeleteBucket",
        "s3:DeleteObject"
      ],
      "Resource": "*"
    }
  ]
}


----------------------------------------------------------------------
Additional Policy – EC2 Limited Access
----------------------------------------------------------------------


Description:
- View EC2 instances
- Start/Stop instances
- Cannot terminate instances


Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ViewInstances",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeInstanceStatus"
      ],
      "Resource": "*"
    },
    {
      "Sid": "StartStop",
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyTerminate",
      "Effect": "Deny",
      "Action": "ec2:TerminateInstances",
      "Resource": "*"
    }
  ]
}


----------------------------------------------------------------------
Important IAM Concepts
----------------------------------------------------------------------


- Explicit Deny overrides Allow
- Follow the Principle of Least Privilege
- IAM actions are case-sensitive
- "Resource": "*" applies to all resources
- Conditions allow fine-grained access control


----------------------------------------------------------------------
How to Create Policy in AWS Console
----------------------------------------------------------------------


1. Go to AWS Console
2. Open IAM
3. Click Policies
4. Click Create Policy
5. Select JSON tab
6. Paste policy
7. Review & Create


-----------------------------------------------------------------