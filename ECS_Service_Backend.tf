locals {
  backend_container = { "name" = "solarstan-backend-${var.environment}", "port" = 80 }
}

module "service_backend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "6.7.0"

  name                           = "${local.backend_container.name}"
  cluster_arn                    = module.ecs_cluster.arn
  iam_role_arn                   = aws_iam_role.ecs_service_role.arn
  task_exec_iam_role_arn         = aws_iam_role.ecs_task_execution_role.arn
  tasks_iam_role_arn             = aws_iam_role.ecs_task_role.arn
  enable_execute_command         = true
  availability_zone_rebalancing  = "DISABLED"
  ignore_task_definition_changes = true
  create_task_exec_iam_role      = false
  create_iam_role                = false
  create_tasks_iam_role          = false
  create_task_exec_policy        = false

  cpu                      = 256
  memory                   = 512
  desired_count            = 1
  autoscaling_max_capacity = 2
  autoscaling_min_capacity = 1

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  requires_compatibilities           = tolist(toset([for t in try(var.cluster_config.launch_types, ["FARGATE_SPOT"]) : contains(["EC2", "EC2_SPOT"], upper(t)) ? "EC2" : "FARGATE"]))
  capacity_provider_strategy         = local.service_capacity_provider_map
  ordered_placement_strategy = {
    binpak = {
      type  = "binpack"
      field = "memory"
    },
    binpak = {
      type  = "binpack"
      field = "cpu"
    }
  }

  container_definitions = {
    "${local.backend_container.name}" = {
      cpu       = 256
      memory    = 256
      essential = true
      image = "161805785056.dkr.ecr.us-east-1.amazonaws.com/ecs-enterprise-backend:production-2289ede"
      portMappings = [
        {
          name          = "http"
          containerPort = local.backend_container.port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl http://localhost/health || exit 1"
        ]
      }

      readonlyRootFilesystem                 = false
      enable_cloudwatch_logging              = true
      cloudwatch_log_group_retention_in_days = 7
      environmentFiles = [
        {
          type  = "s3"
          value = "arn:aws:s3:::${var.secrets_s3_bucket.bucket_name}/${var.environment}/secrets/.env"
        }
      ]

      memoryReservation = 100
      restartPolicy = {
        enabled              = true
        ignoredExitCodes     = [1]
        restartAttemptPeriod = 60
      }
    }
  }


  service_connect_configuration = {
    namespace = "${aws_service_discovery_http_namespace.namespace.name}"
    service = [{
      client_alias = {
        port     = local.backend_container.port
        dns_name = "${local.backend_container.name}"
      }
      port_name      = "http"
      discovery_name = "${local.backend_container.name}"
    }]
  }

    load_balancer = {
    frontend_service = {
      target_group_arn = "${aws_lb_target_group.backend_blue.arn}"
      container_name   = "${local.backend_container.name}"
      container_port   = "${local.backend_container.port}"
      #   advanced_configuration = { # For Blue Green
      #     role_arn                   = aws_iam_role.ecs_service_role.arn # ECS IAM Role with AmazonEC2ContainerServiceRole 
      #     production_listener_rule   = aws_lb_listener_rule.frontend.arn
      #     alternate_target_group_arn = aws_lb_target_group.frontend_green.arn
      #     test_listener_rule         = aws_lb_listener_rule.frontend_test.arn
      #   }
    }
  }

  subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_cidr_blocks
  security_group_ids = [data.terraform_remote_state.vpc.outputs.security_group_ids["backend_sg"]]

  tags = {
    Environment = "${var.environment}"
  }

}


# Outputs: <NAME>_<PARAMETER_NAME>
output "BACKEND_TASK_DEFINITION_NAME" {
  value = local.backend_container.name
}
output "BACKEND_SERVICE_NAME" {
  value = module.service_backend.name
}
output "BACKEND_REGISTRY" {
  value = data.terraform_remote_state.base.outputs.backend_aws_ecr_repository
}

# ADDITIONAL TASK DEFINITION CONFIGS

# logConfiguration = {
#   logConfiguration = {
#     logDriver = "awslogs"
#     options = {
#       awslogs-group         = "/aws/ecs"
#       awslogs-region        = "us-east-1"
#       awslogs-stream-prefix = "ecs"
#     }
#   }
# }

# load_balancer = {
#   service = {
#     target_group_arn = ""
#     container_name   = "${local.backend_container.name}"
#     container_port   = "${local.backend_container.port}"
#   }
# }


# security_group_ingress_rules = {
#   alb_access = {
#     description                  = "Service port"
#     from_port                    = local.backend_container.port
#     ip_protocol                  = "tcp"
#     reference_security_group_id  = ""
#   }
# }
# security_group_egress_rules = {
#   all = {
#     ip_protocol = "-1"
#     cidr_ipv4   = "0.0.0.0/0"
#   }
# }