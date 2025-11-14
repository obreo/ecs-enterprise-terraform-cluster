# ECS Enterprise - ECS - VPC
This infrastructure defines AWS ECS cluster using the AWS ECS community Terraform module.

This infrastructure is structured to deploy in phases, and integrates with GitOps workflow that supports multi environment architecture. It is planned as follows:

1. `Base/`directory shares a number of resources for all environments. The resources inside this directory are deployed individually using a seperate Terraform state. They are triggered only during the development environment CD workflow.
*    `LifecycleHooks`: A part of `Base/` deployment, used to deploy lambda functions to test the native ECS Blue/Green traffic.
2. Environment based workflow: designed to deploy ECS resources in development, staging, and production environments with seperate Terraform state per each.
*   Application Load Balancer: along with target groups and listeners related to every service.
*   ECS EC2 Autoscaling: Manages the EC2 autoscaling group with ECS related functions. It it created dynamically based on the provider type in the varaibles, so generally it can be ignored unless needed.
*   ECS Cluster: Dynamic to deploy EC2, FARGATE, or SPOT types using `variables.tfvars` per environment, including the instance type and autoscaling management.
*   ECS Roles: Perpares the neccessary IAM roles for ECS IAM role, ECS Task role, and ECS Task Execution role. It includes reading secrests from S3 buckets and invoking lambda functions for blue green strategy testing.
*   ECS Services: Every `ECS_Service_*.tf` includes the task definition configuration for the application. As for an organized workflow, every service is prepared with the default configuations and basic changes that can be stated in the [below](#ECS_Service_Configuration)
*   Variables: Defined variables that can be controlled in `environments/ENV/variables.tfvars`.

# GitOps Workflow

This module integrates with GitHub Actions workflow using OpenID Connect (OIDC) to authenticate with AWS:

1. Clones the source repository.
2. Initiates Terraform using the environment state file.
3. Executes Plan and Apply using `environmets/ENV/variables.tfvars`.

# Prerequisites

1. Terraform
2. Configured AWS CLI
3. Private S3 bucket with PutObject and GetObject permissions to store Terraform states.

# How to Use Template

1. Clone the main branch.
2. Configure `environments/ENVIRONMENT/backend.tfvars` to connect to the S3 bucket per environment.
3. Configure `environments/ENVIRONMENT/variables.tfvars`.tfvars with the required environment variables.

# How to Deploy

```
# (OPTIONAL) Deploy Base/
terraform -chdir=Base/ init -backend-config="../environments/Base/backend.tfvars" -var-file="../environments/Base/variables.tfvars"

# Deploy Infra
terraform init -backend-config="environments/ENV/backend.tfvars" -var-file="../environments/ENV/variables.tfvars" -reconfigure

terraform plan -var-file "environments/ENV/ENV.tfvars" -out=tfplan

terraform apply "tfplan"
```

# ECS Cluster Config

* The cluster resource depends on locals block, which defines a number of keys that allow to choose the ECS type, and instance type dynamically.

* It configures `autoscaling_capacity_providers` with EC2 and EC2 Spot blocks with some hardcoded values that can be modified in place.

* It configures `default_capacity_provider_strategy` blocks with some hardcoded values that can be modified in place.

* Both of the capacity providers and the capacity provider stratigy blocks are picked dynamically based on the variables value.


# ECS Service Config

* It uses a local block that defines a task name and port.
* By default, it uses the created IAM roles in this project. The default ones are disabled.
* The Service is set to ignore task definition chnages to not conflict with the CI/CD container updates for the application.
* The rest of parameters use the local block id.
* By default, the service connect is created.
* When modifying the service name and block id, make sure to modify what connects to it from both the service parameters and output blocks.

# GitHub Actions Workflow

To use the workflow:

Define the variables in `workflow.yml:

```
role-to-assume: ${{secrets.OIDC_ROLE_ARN}}
BACKEND: 'environments/ENV/backend.tfvars'
VARIABLES: 'environments/ENV/variables.tfvars'
REGION: ${{vars.AWS_REGION}}
(optional) SECRETS_BUCKET: ${{secrets.AWS_S3_BUCKET_FOR_ECS_SECRETS}}
```

# Troubleshooting

1. If task kept failing and logs are failing to load, it could be the image was not loaded. This could be due to no IAM role (Task execution role), Wrong image, or no internet connection (check NAT and route tables).
2. If task kept failing as (1) but image and connection were verified, it could be misconfiguration of the task definition (mispositioned parameter, capacity type not matching with cluster..etc)
3. If log showed connection to s3 bucket unauthorized, check the Task role and make sure it is allowed to access the relevant S3 bucket.
4. If ECSExec was failing to load service container, check Service IAM role to allow `ssmmessages` actions.
5. If EC2 autoscaling group was defined by ECS cluser but registered container instances were not recognized, make sure the Autoscaling group uses launch template that registers the ECS cluster name in at `/etc/ecs/ecs.config`when launching new instance. Check Autoscaling group resource for further info.

# Pending - Requires troubleshooting

* ECS Native Blue Green did not success due to target group not being recognized by the ECS cluster despite meeting the requirements mentioned in AWS documentation.

# Resources

[ECS Blue / Green Lifecycle Hooks](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-lifecycle-hooks.html)
[ECS Blue / Green Lifecycle Hooks Examples](https://github.com/aws-samples/sample-amazon-ecs-blue-green-deployment-patterns/blob/main/ecs-bluegreen-lifecycle-hooks/README.md)
[Terraform ECS Service Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)
[Terraform ECS module](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws/latest/)
[Terraform Lambda module](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/latest)
