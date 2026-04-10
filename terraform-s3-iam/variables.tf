variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environments" {
  description = "Map of environment configurations"
  type = map(object({
    bucket_suffix                      = string
    versioning                         = bool
    users                              = list(string)
    lifecycle_rules = list(object({
      id                              = string
      status                          = string
      transitions                     = list(object({
        days                          = number
        storage_class                 = string
      }))
      expiration_days                 = number
      noncurrent_version_expiration_days = number
    }))
  }))

  default = {
    dev = {
      bucket_suffix = "data-2024"
      versioning    = true
      users         = ["alice", "bob", "charlie"]
      lifecycle_rules = [
        {
          id     = "transition-to-ia"
          status = "Enabled"
          transitions = [
            {
              days          = 30
              storage_class = "STANDARD_IA"
            },
            {
              days          = 90
              storage_class = "GLACIER"
            }
          ]
          expiration_days                 = 0
          noncurrent_version_expiration_days = 7
        }
      ]
    }
    staging = {
      bucket_suffix = "data-staging"
      versioning    = true
      users         = ["bob", "dave", "eve"]
      lifecycle_rules = [
        {
          id     = "cleanup-old-versions"
          status = "Enabled"
          transitions = []
          expiration_days                 = 0
          noncurrent_version_expiration_days = 30
        }
      ]
    }
    prod = {
      bucket_suffix = "data-prod"
      versioning    = true
      users         = ["charlie", "dave", "frank"]
      lifecycle_rules = [
        {
          id     = "prod-lifecycle"
          status = "Enabled"
          transitions = [
            {
              days          = 60
              storage_class = "STANDARD_IA"
            }
          ]
          expiration_days                 = 365
          noncurrent_version_expiration_days = 90
        }
      ]
    }
  }
}
