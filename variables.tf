variable "cluster_name" {
  description = "cluster name per envrionment"
  type        = string
}

variable "environment" {
  description = "Infrastructure environment"
  type        = string
}

variable "domain" {
  description = "Primary domain name for services"
  type        = string
}

variable "loadbalancer" {
  description = "Loadbalancer configuration"
  type = object({
    enable_http  = bool
    enable_https = bool
  })
  default = {
    enable_http  = true
    enable_https = false
  }
}

variable "secrets_s3_bucket" {
  description = "S3 bucket for secrets fetching"
  type = object({
    enable_secrets_bucket = optional(bool, false)
    bucket_name           = optional(string, "")
  })
}


variable "cluster_config" {
  type = object({
    launch_types  = optional(list(string), ["FARGATE_SPOT"])
    instance_type = optional(list(string), [""])
  })

  validation {
    condition = alltrue([
      for t in try(var.cluster_config.launch_types, ["FARGATE_SPOT"]) :
      contains(["EC2", "EC2_SPOT", "FARGATE", "FARGATE_SPOT"], upper(t))
    ])
    error_message = "launch_type must be one of: EC2, EC2_SPOT, FARGATE, FARGATE_SPOT."
  }
}

# Collect Info outputs from VPC module:

variable "terraform_remote_outputs_vpc" {
  description = "Terraform remote state outputs configuration"
  type = object({
    s3_bucket = string
    s3_key    = string
  })
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.terraform_remote_outputs_vpc.s3_bucket
    key    = var.terraform_remote_outputs_vpc.s3_key
    region = "us-east-1"
  }
}

variable "terraform_remote_outputs_base" {
  description = "Terraform remote state outputs configuration"
  type = object({
    s3_bucket = string
    s3_key    = string
  })
}
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = var.terraform_remote_outputs_base.s3_bucket
    key    = var.terraform_remote_outputs_base.s3_key
    region = "us-east-1"
  }
}

