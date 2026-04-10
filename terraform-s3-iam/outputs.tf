output "bucket_names" {
  description = "S3 bucket names"
  value = {
    for env, bucket in aws_s3_bucket.environment_buckets : env => bucket.bucket
  }
}

output "bucket_arns" {
  description = "S3 bucket ARNs"
  value = {
    for env, bucket in aws_s3_bucket.environment_buckets : env => bucket.arn
  }
}

output "iam_users" {
  description = "IAM users"
  value = {
    for user in aws_iam_user.users : user.name => {
      arn          = user.arn
      environments = local.user_env_map[user.name]
    }
  }
}

output "environment_policies" {
  description = "IAM policies"
  value = {
    for env, policy in aws_iam_policy.environment_policies : env => {
      name = policy.name
      arn  = policy.arn
    }
  }
}

output "user_environment_access" {
  description = "User environment mapping"
  value = local.user_env_map
}
