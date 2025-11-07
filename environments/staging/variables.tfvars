cluster_name = "ecs-enterprise"
environment = "staging"

domain = "abralabs.com"

terraform_remote_outputs_vpc = {
    s3_bucket     = "abra-terraform-states"
    s3_key        = "ecs-enterprise/staging/vpc/terraform.tfstate"
}

loadbalancer = {
    enable_http          = true
    enable_https         = false
}

secrets_s3_bucket = {
    enable_secrets_bucket = false
    bucket = ""
}