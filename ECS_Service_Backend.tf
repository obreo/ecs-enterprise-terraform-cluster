locals {
  backend_container = { "name" = "solarstan-backend", "port" = 5000 }
}

module "service_backend" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "6.7.0"

  name                          = local.backend_container.name
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

  capacity_provider_strategy = {
    EC2 = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["EC2"].name
      base              = 1
      weight            = 1
    }
  }


  # Container definition(s)
  container_definitions = {
    "${local.backend_container.name}" = {
      cpu       = 256
      memory    = 256
      essential = true
      image     = "public.ecr.aws/nginx/nginx:latest"
      portMappings = [
        {
          name          = "http"
          containerPort = local.backend_container.port
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost/ || exit 1"
        ]
      }

      # Example image used requires access to write to root filesystem
      #   readonlyRootFilesystem = false

      #   dependsOn = [{
      #     containerName = ""
      #     condition     = "START"
      #   }]

      readonlyRootFilesystem                 = false
      enable_cloudwatch_logging              = true
      cloudwatch_log_group_retention_in_days = 7
      logConfiguration = {
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/aws/ecs"
            awslogs-region        = "us-east-1"
            awslogs-stream-prefix = "ecs"
          }
        }
      }

      memoryReservation = 100
      restartPolicy = {
        enabled              = true
        ignoredExitCodes     = [1]
        restartAttemptPeriod = 60
      }
    }
  }

  requires_compatibilities = ["EC2"]
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

  subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_cidr_blocks
  security_group_ids = [data.terraform_remote_state.vpc.outputs.security_group_ids["backend_sg"]]

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

  tags = {
    Environment = "${var.environment}"
  }
}


