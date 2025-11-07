module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.cluster_name}"
  description   = "ecs_post_traffic_test lifecycle"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "src/post_traffic_test.py"

  tags = {
    Name = "${var.cluster_name}"
  }
}