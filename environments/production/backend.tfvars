    bucket       = "abra-terraform-states"
    key          = "ecs-enterprise/production/ecs/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true


    # This setup assumes there is a secured S3 bucket already created to store Terraform state file.
    # bash: aws s3 mb s3://amzn-s3-demo-bucket --region us-west-1