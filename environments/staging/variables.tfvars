cluster_name = "ecs-enterprise"
environment = "staging"

domain = "staging.abralabs.com"

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

cluster_config = {
    launch_types = ["FARGATE_SPOT"]
    instance_type = [""]
}