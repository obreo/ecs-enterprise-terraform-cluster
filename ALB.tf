################################################################################
#
# ALB
#
################################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "load_balancer" {
  name                       = "${var.cluster_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [data.terraform_remote_state.vpc.outputs.security_group_ids["alb_sg"]]
  subnets                    = data.terraform_remote_state.vpc.outputs.public_subnet_cidr_blocks
  enable_deletion_protection = false
  tags = {
    Environment = "${var.environment}"
  }
}


################################################################################
#
# Target Group
#
################################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group-
# Frontend
resource "aws_lb_target_group" "frontend_blue" {
  name                 = "${var.cluster_name}-${var.environment}"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 30 # seconds
  health_check {
    enabled             = true
    port                = 80
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202,302"
    path                = "/"
  }
  stickiness {
    enabled         = true
    cookie_duration = 86400 # Seconds = 1 Day
    type            = "lb_cookie"
  }

  tags = {
    "Environment" = "${var.environment}"
    "Tier"        = "Frontend"
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}

resource "aws_lb_target_group" "backend_blue" {
  name                 = "${var.cluster_name}-${var.environment}-bb"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 30 # seconds
  health_check {
    enabled             = true
    port                = 80
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202,302"
    path                = "/health"
  }
  stickiness {
    enabled         = true
    cookie_duration = 86400 # Seconds = 1 Day
    type            = "lb_cookie"
  }

  tags = {
    "Environment" = "${var.environment}"
    "Tier"        = "Frontend"
  }

  depends_on = [
    aws_lb.load_balancer
  ]
}


################################################################################
#
# Listener & Listener rule
#
################################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
# Doc: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = var.loadbalancer.enable_https == "true" ? "443" : "80" # HTTP 80 used, for HTTPS 443 port there must be a TLS certificate defined.
  protocol          = var.loadbalancer.enable_https == "true" ? "HTTPS" : "HTTP"
  ssl_policy        = var.loadbalancer.enable_https == "true" ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = var.loadbalancer.enable_https == "true" ? "${var.loadbalancer.certificate_arn}" : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_blue.arn
  }

  # lifecycle {
  #   ignore_changes = all
  # }

  depends_on = [
    aws_lb.load_balancer
  ]
}

# resource "aws_lb_listener" "listener_test" {
#   load_balancer_arn = aws_lb.load_balancer.arn
#   port              = "8080"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.frontend_green.arn
#   }

#   # lifecycle {
#   #   ignore_changes = all
#   # }

#   depends_on = [
#     aws_lb.load_balancer
#   ]
# }

################################################################################
#
# RULES
#
################################################################################
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_blue.arn
  }

  condition {
    host_header {
      values = ["${var.domain}"]
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  # lifecycle {
  #   ignore_changes = all
  # }

  depends_on = [
    aws_lb.load_balancer
  ]
}

resource "aws_lb_listener_rule" "backend_blue" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_blue.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  # lifecycle {
  #   ignore_changes = all
  # }

  depends_on = [
    aws_lb.load_balancer
  ]
}

resource "aws_lb_listener_rule" "backend_health" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 4

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_blue.arn
  }

  condition {
    path_pattern {
      values = ["/health/*"]
    }
  }

  # lifecycle {
  #   ignore_changes = all
  # }

  depends_on = [
    aws_lb.load_balancer
  ]
}