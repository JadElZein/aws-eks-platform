locals {
  github_roles = {
    plan = {
      sub        = "${local.github_sub_prefix}:pull_request"
      policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    }
    apply = {
      sub        = "${local.github_sub_prefix}:ref:refs/heads/main"
      policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
  }
}

data "aws_iam_policy_document" "github_trust" {
  for_each = local.github_roles

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
      values   = [each.value.sub]
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.github_roles

  name               = "github-${local.github_repo}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.github_trust[each.key].json
}

resource "aws_iam_role_policy_attachment" "github" {
  for_each = local.github_roles

  role       = aws_iam_role.github[each.key].name
  policy_arn = each.value.policy_arn
}

# Even a plan writes a lock file to the state bucket, so the read-only
# role needs write access to that file only.
resource "aws_iam_role_policy" "plan_state_lock" {
  name = "state-lock-file"
  role = aws_iam_role.github["plan"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "${aws_s3_bucket.tfstate.arn}/*.tflock"
    }]
  })
}

output "github_role_names" {
  value = { for k, r in aws_iam_role.github : k => r.name }
}
