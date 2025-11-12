output "frontend_aws_ecr_repository" {
  value = aws_ecr_repository.frontend.repository_url
}
output "backend_aws_ecr_repository" {
  value = aws_ecr_repository.backend.repository_url
}