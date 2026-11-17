data "aws_iam_policy_document" "github_push_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.github_sub_prefix}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_push" {
  name               = "github-${local.github_repo}-push"
  assume_role_policy = data.aws_iam_policy_document.github_push_trust.json
}

resource "aws_iam_role_policy" "push_ecr" {
  name = "ecr-push"
  role = aws_iam_role.github_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # AWS only allows this one on *
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

output "github_push_role_name" {
  value = aws_iam_role.github_push.name
}
