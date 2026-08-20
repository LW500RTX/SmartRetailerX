# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "smartretailx-cluster-${var.environment}"

  tags = {
    Name        = "${var.project_name}-ecs-cluster"
    Environment = var.environment
  }
}
