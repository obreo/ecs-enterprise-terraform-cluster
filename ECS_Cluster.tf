module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "6.7.0"

  # Cluster 
  name = var.cluster_name
  configuration = {
    # Enable Container Insights - logging and monitoring
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.cluster_name}"
      }
    }
  }

  autoscaling_capacity_providers = { # For EC2 cluster capacity providers
    # On-demand instances
    EC2 = {
      auto_scaling_group_arn         = module.autoscaling["EC2"].autoscaling_group_arn
      managed_draining               = "ENABLED"
      managed_termination_protection = "ENABLED" # Should be synced with asg termination protection.

      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 100
      }
    }

    # Spot instances
    # EC2_SPOT = {
    #     auto_scaling_group_arn         = module.autoscaling["EC2_SPOT"].autoscaling_group_arn
    #     managed_draining               = "ENABLED"
    #     managed_termination_protection = "ENABLED"

    #     managed_scaling = {
    #         maximum_scaling_step_size = 5
    #         minimum_scaling_step_size = 1
    #         status                    = "ENABLED"
    #         target_capacity           = 90
    #     }
    # }
  }

  # Cluster capacity providers
  default_capacity_provider_strategy = {
    # FARGATE = {
    #   weight = 50
    #   base   = 1
    # }
    # FARGATE_SPOT = {
    # weight = 30
    # }
    EC2 = { # On-demand instances - can be any name defined in autoscaling_capacity_providers
      weight = 70
      base   = 1
    }
  }

  tags = {
    Environment = "${var.environment}"
    Project     = "EcsEc2"
  }

  create_task_exec_iam_role = true
  create_task_exec_policy   = true
}


resource "aws_service_discovery_http_namespace" "namespace" {
  name        = "${var.cluster_name}-${var.environment}.local"
  description = "used for ${var.cluster_name}-${var.environment}.local"
}