cluster_name = "ecs-enterprise"
environment = "development"

domain = "dev.abralabs.com"

terraform_remote_outputs_vpc = {
    s3_bucket     = "abra-terraform-states"
    s3_key        = "ecs-enterprise/staging/vpc/terraform.tfstate"
}

terraform_remote_outputs_base = {
    s3_bucket     = "abra-terraform-states"
    s3_key        = "ecs-enterprise/base/terraform.tfstate"
}

loadbalancer = {
    enable_http          = true
    enable_https         = false
}

secrets_s3_bucket = {
    enable_secrets_bucket = true
    bucket_name = "ecs-enterprise"
}

cluster_config = {
    launch_types = ["FARGATE_SPOT"]
    instance_type = [""]
}