# locals
locals {
  # Pick launch type from variables
  launch_types   = [for t in try(var.cluster_config.launch_types, ["FARGATE_SPOT"]) : upper(t)]
  instance_types = try(var.cluster_config.instance_type, ["t3.medium"]) # list

  # Determine which providers are in use
  use_ec2     = length([for t in local.launch_types : t if t == "EC2" || t == "EC2_SPOT"]) > 0
  use_fargate = length([for t in local.launch_types : t if t == "FARGATE" || t == "FARGATE_SPOT"]) > 0
  use_spot    = length([for t in local.launch_types : t if t == "EC2_SPOT" || t == "FARGATE_SPOT"]) > 0

  # Dynamically build autoscaling capacity providers (EC2 only)
  autoscaling_capacity_providers = merge(
    contains(local.launch_types, "EC2") ? {
      EC2 = {
        auto_scaling_group_arn         = module.autoscaling["EC2"].autoscaling_group_arn
        managed_draining               = "ENABLED"
        managed_termination_protection = "ENABLED"

        managed_scaling = {
          maximum_scaling_step_size = 5
          minimum_scaling_step_size = 1
          status                    = "ENABLED"
          target_capacity           = 100
        }
      }
    } : {},

    contains(local.launch_types, "EC2_SPOT") ? {
      EC2_SPOT = {
        auto_scaling_group_arn         = try(module.autoscaling["EC2_SPOT"].autoscaling_group_arn, null)
        managed_draining               = "ENABLED"
        managed_termination_protection = "ENABLED"

        managed_scaling = {
          maximum_scaling_step_size = 4
          minimum_scaling_step_size = 1
          status                    = "ENABLED"
          target_capacity           = 100
        }
      }
    } : {}
  )

  # Dynamic default capacity provider strategy
  default_capacity_provider_strategy = merge(
    contains(local.launch_types, "FARGATE") ? {
      FARGATE = {
        weight = 50
        base   = 1
      }
    } : {},
    contains(local.launch_types, "FARGATE_SPOT") ? {
      FARGATE_SPOT = {
        weight = 30
      }
    } : {},
    contains(local.launch_types, "EC2") ? {
      EC2 = {
        weight = 70
        base   = 1
      }
    } : {},
    contains(local.launch_types, "EC2_SPOT") ? {
      EC2_SPOT = {
        weight = 30
      }
    } : {}
  )

  service_capacity_provider_map = {
    for k, v in local.default_capacity_provider_strategy : k => {
      capacity_provider = contains(["EC2", "EC2_SPOT"], k) ? module.ecs_cluster.autoscaling_capacity_providers[k].name : k
      weight            = v.weight
      base              = try(v.base, 0)
    }
  }
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "6.7.0"

  # Cluster 
  name = "${var.cluster_name}-${var.environment}"
  configuration = {
    # Enable Container Insights - logging and monitoring
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.cluster_name}"
      }
    }
  }

  autoscaling_capacity_providers = local.autoscaling_capacity_providers

  # Cluster capacity providers
  default_capacity_provider_strategy = local.default_capacity_provider_strategy

  tags = {
    Environment = "${var.environment}"
    Project     = "${var.cluster_name}"
  }

  create_task_exec_iam_role = true
  create_task_exec_policy   = true
}


resource "aws_service_discovery_http_namespace" "namespace" {
  name        = "${var.cluster_name}-${var.environment}.local"
  description = "used for ${var.cluster_name}-${var.environment}.local"
}

output "CLUSTER_NAME" {
  value = module.ecs_cluster.name
}