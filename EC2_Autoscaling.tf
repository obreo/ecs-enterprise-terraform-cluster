# locals

locals {

  # Base user_data shared by both
  base_user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${var.cluster_name}-${var.environment}
    ECS_LOGLEVEL=debug
    ECS_ENABLE_TASK_IAM_ROLE=true
  EOT

  # On-demand EC2
  ec2_ondemand = {
    instance_type              = local.instance_types[0]
    use_mixed_instances_policy = false
    mixed_instances_policy     = null
    user_data                  = "${local.base_user_data}\nEOF"
  }


  # Spot EC2
  ec2_spot = {
    instance_type              = local.instance_types[0]
    use_mixed_instances_policy = true
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_base_capacity                  = 0
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "price-capacity-optimized"
      }
      launch_template = {
        override = [
          for itype in local.instance_types : {
            instance_type     = itype
            weighted_capacity = "1"
          }
        ]
      }
    }
    user_data = "${local.base_user_data}\nECS_ENABLE_SPOT_INSTANCE_DRAINING=true\nEOF"
  }
  # Build final autoscaling map dynamically
  autoscaling_map = merge(
    local.use_ec2 ? { EC2 = local.ec2_ondemand } : {},
    local.use_spot ? { EC2_SPOT = local.ec2_spot } : {}
  )
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0"

  for_each = local.autoscaling_map

  name = "${var.cluster_name}-autoscaling-${each.key}"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = each.value.instance_type

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(each.value.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = "EC2-${var.cluster_name}-${var.environment}"
  iam_role_description        = "ECS role for ${var.cluster_name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = data.terraform_remote_state.vpc.outputs.private_subnet_cidr_blocks
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 5
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  # Spot instances
  use_mixed_instances_policy = each.value.use_mixed_instances_policy
  mixed_instances_policy     = each.value.mixed_instances_policy

  tags = {
    Environment = "${var.environment}"
  }
}

# Allowing ALB to connect to EC2 cluster
module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

  name        = "asg-${var.cluster_name}-${var.environment}"
  description = "Autoscaling group security group"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = "${data.terraform_remote_state.vpc.outputs.security_group_ids["alb_sg"]}"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = {
    Environment = "${var.environment}"
  }
}