locals {
  frontend_container = { "name" = "solarstan-frontend", "port" = 80 }
}

module "service_frontend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "6.7.0"

  name                          = local.frontend_container.name
  cluster_arn                   = module.ecs_cluster.arn
  iam_role_arn                  = aws_iam_role.ecs_service_role.arn
  task_exec_iam_role_arn        = aws_iam_role.ecs_task_execution_role.arn
  tasks_iam_role_arn            = aws_iam_role.ecs_task_role.arn
  enable_execute_command        = true
  availability_zone_rebalancing = "DISABLED"

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
      field = "cpu"
    }
  }

  container_definitions = {
    "${local.frontend_container.name}" = {
      cpu       = 256
      memory    = 256
      essential = true
      image     = "public.ecr.aws/nginx/nginx:latest"
      portMappings = [
        {
          name          = "http"
          containerPort = local.frontend_container.port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl http://localhost/ || exit 1"
        ]
      }

      readonlyRootFilesystem                 = false
      enable_cloudwatch_logging              = true
      cloudwatch_log_group_retention_in_days = 7


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
        port     = local.frontend_container.port
        dns_name = "${local.frontend_container.name}"
      }
      port_name      = "http"
      discovery_name = "${local.frontend_container.name}"
    }]
  }

  load_balancer = {
    frontend_service = {
      target_group_arn = "${aws_lb_target_group.frontend_blue.arn}"
      container_name   = "${local.frontend_container.name}"
      container_port   = "${local.frontend_container.port}"
    #   advanced_configuration = { # For Blue Green
    #     role_arn                   = aws_iam_role.ecs_service_role.arn # ECS IAM Role with AmazonEC2ContainerServiceRole 
    #     production_listener_rule   = aws_lb_listener_rule.frontend.arn
    #     alternate_target_group_arn = aws_lb_target_group.frontend_green.arn
    #     test_listener_rule         = aws_lb_listener_rule.frontend_test.arn
    #   }
    }
  }

  deployment_configuration = {
    strategy             = "ROLLING"
    bake_time_in_minutes = 0
    # lifecycle_hook = {        # For Blue Green
    #   "TEST_TRAFFIC_SHIFT" = {
    #     hook_target_arn  = data.terraform_remote_state.base.outputs.lambda_post_traffic_arn # lambda function
    #     role_arn         = "${aws_iam_role.ecs_service_role.arn}"                           # invoke lambda role
    #     lifecycle_stages = ["POST_TEST_TRAFFIC_SHIFT"]                                      # lifecycle hook stage
    #     hook_details = jsonencode({                                                         # what should be passed to the lambda event json.
    #       TestEndpoint = "http://${aws_lb.load_balancer.dns_name}:8080/"
    #     })
    #   }
    }

  subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_cidr_blocks
  security_group_ids = [data.terraform_remote_state.vpc.outputs.security_group_ids["frontend_sg"], module.autoscaling_sg.security_group_id]

  tags = {
    Environment = "${var.environment}"
  }
}

# Outputs: <NAME>_<PARAMETER_NAME>
output "FRONTEND_TASK_DEFINITION_NAME" {
  value = local.frontend_container.name
}
output "FRONTEND_SERVICE_NAME" {
  value = module.service_frontend.name
}
output "FRONTEND_REGISTRY" {
  value = data.terraform_remote_state.base.outputs.frontend_aws_ecr_repository
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

# security_group_ingress_rules = {
#   alb_access = {
#     description                  = "Service port"
#     from_port                    = local.frontend_container.port
#     ip_protocol                  = "tcp"
#     reference_security_group_id  = "${data.terraform_remote_state.vpc.outputs.security_group_ids["ecs-enterprise-alb"]}"
#   }
# }
# security_group_egress_rules = {
#   all = {
#     ip_protocol = "-1"
#     cidr_ipv4   = "0.0.0.0/0"
#   }
# }
