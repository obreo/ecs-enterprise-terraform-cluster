######################################################
# Default ECS service role for EC2
# Only if you enable load_balancer block
######################################################
# resource "aws_iam_role" "ecs_service_role" {
#   name = "ecs_service_role_${var.environment}"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "ecs.amazonaws.com" # Note: ecs.amazonaws.com, NOT ecs-tasks
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_service_role_policy" {
#   role       = aws_iam_role.ecs_service_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
# }


######################################################
# Task Execution Role
# This is given to ECS to get the image and write logs in cloudwatch - role is executed on the task definition level.
######################################################
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_${var.environment}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Policy Attachment
# To get ECR image and write logs in cloudwatch
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs_service_role_policyy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}
# ECS Full Access
resource "aws_iam_role_policy_attachment" "ecs_full_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}
# To get parameters from SSM - if needed
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}
# To create EBS volume- if needed
resource "aws_iam_role_policy_attachment" "ebs" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes"
}
# To get .env file from S3 bucket - if needed
resource "aws_iam_role_policy_attachment" "custom_ecs_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.custom_ecs_policy.arn
}
resource "aws_iam_policy" "custom_ecs_policy" {
  name        = "custom_ecs_policy_${var.environment}"
  path        = "/"
  description = "Additional policies given to ECS task and task execution"
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.secrets_s3_bucket.enable_secrets_bucket ? var.secrets_s3_bucket.bucket_name : "no-bucket"}/secrets/*",
        ]
      },
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunctionUrl",
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:*:161805785056:function:*"
      }
    ]
  })

}

######################################################
# Task Role
# This is given to ECS tasks to execute AWS permissions inside the container - role is executed on the container level.
######################################################
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs_task_${var.environment}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "ecs_task_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# To get .env file from S3 bucket - if needed
resource "aws_iam_role_policy_attachment" "custom_ecs_policy_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.custom_ecs_policy.arn
}




