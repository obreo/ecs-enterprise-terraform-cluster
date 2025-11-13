variable "cluster_name" {
  description = "cluster name per envrionment"
  type        = string
}

variable "secrets_s3_bucket" {
  description = "S3 bucket for secrets fetching"
  sensitive = true
  type = object({
    enable_secrets_bucket = optional(bool, false)
    bucket_name           = optional(string, "")
    identifiers           = optional(string, "")
  })
}