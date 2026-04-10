
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "myapp-terraform-state-ACCOUNT_ID"
    key            = "s3-iam/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "myapp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

locals {
  all_users = flatten([
    for env, config in var.environments : [
      for user in config.users : {
        username    = user
        environment = env
      }
    ]
  ])

  unique_users = toset(distinct([
    for u in local.all_users : u.username
  ]))

  user_env_map = {
    for username in local.unique_users : username => [
      for u in local.all_users : u.environment if u.username == username
    ]
  }
}

resource "aws_s3_bucket" "environment_buckets" {
  for_each = var.environments

  bucket = "myapp-${each.key}-${each.value.bucket_suffix}"

  tags = {
    Environment = each.key
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "environment_buckets" {
  for_each = {
    for env, config in var.environments : env => config
    if config.versioning
  }

  bucket = aws_s3_bucket.environment_buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "environment_buckets" {
  for_each = var.environments

  bucket = aws_s3_bucket.environment_buckets[each.key].id

  dynamic "rule" {
    for_each = each.value.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.status

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days > 0 ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days > 0 ? [rule.value.noncurrent_version_expiration_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }
    }
  }
}

resource "aws_iam_user" "users" {
  for_each = local.unique_users

  name = each.value

  tags = {
    Environments = join(",", local.user_env_map[each.value])
  }
}

resource "aws_iam_policy" "environment_policies" {
  for_each = var.environments

  name        = "myapp-${each.key}-bucket-access"
  description = "Access policy for ${each.key} environment S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = aws_s3_bucket.environment_buckets[each.key].arn
      },
      {
        Sid    = "AllowObjectOperations"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = "${aws_s3_bucket.environment_buckets[each.key].arn}/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "user_environment_access" {
  for_each = {
    for pair in setproduct(
      keys(var.environments),
      local.unique_users
    ) : "${pair[0]}-${pair[1]}" => {
      environment = pair[0]
      username    = pair[1]
    }
    if contains(local.user_env_map[pair[1]], pair[0])
  }

  user       = aws_iam_user.users[each.value.username].name
  policy_arn = aws_iam_policy.environment_policies[each.value.environment].arn
}
