# GitLab Runner deployment
resource "aws_iam_user" "deployment" {
  name = "sitecore-ecs-deployment"
  path = "/odin/"

  tags = {
    Team = "odin-platform"
  }
}

resource "aws_iam_access_key" "deployment" {
  user = aws_iam_user.deployment.name
}

resource "aws_iam_user_policy_attachment" "ecs_full_access" {
  user       = aws_iam_user.deployment.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_user_policy_attachment" "remote_backend" {
  user       = aws_iam_user.deployment.name
  policy_arn = "arn:aws:iam::273653477426:policy/odin/TerraformRemoteBackendFullAccess"
}

