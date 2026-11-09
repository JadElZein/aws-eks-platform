data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_owner    = "JadElZein"
  github_owner_id = "280180868"
  github_repo     = "aws-eks-platform"
  github_repo_id  = "1447516549"

  github_sub_prefix = "repo:${local.github_owner}@${local.github_owner_id}/${local.github_repo}@${local.github_repo_id}"
}
