# TEST: pass_match_second_statement
#
# Verifies that override_statement_match correctly identifies the SECOND
# statement in PowerUserAccess (the explicit Action allowlist) and replaces
# it. Tests the Action list code path as opposed to NotAction.
#
# EXPECTED RESULT:
#   - terraform plan succeeds
#   - merged_policy contains 2 statements
#   - First source statement passes through unchanged with SID "0"
#   - Statement with SID "PowerUserLimitedIAMOverride" replaces the second
#     source statement, containing only the 3 permitted iam: actions

override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid    = "PowerUserLimitedIAMOverride"
override_policy_effect = "Allow"

# Replacing the full IAM/account/orgs allowlist with a tighter subset
override_policy_actions = [
  "iam:CreateServiceLinkedRole",
  "iam:DeleteServiceLinkedRole",
  "iam:ListRoles"
]

override_policy_resources  = ["*"]
override_policy_conditions = []

# Copied exactly from PowerUserAccess Statement[1].
# Action is a list in source — must match list form exactly.
# Resource is scalar "*" in source — do not convert to list.
override_statement_match = "{\"Effect\":\"Allow\",\"Action\":[\"account:GetAccountInformation\",\"account:GetGovCloudAccountInformation\",\"account:GetPrimaryEmail\",\"account:ListRegions\",\"iam:CreateServiceLinkedRole\",\"iam:DeleteServiceLinkedRole\",\"iam:ListRoles\",\"organizations:DescribeEffectivePolicy\",\"organizations:DescribeOrganization\"],\"Resource\":\"*\"}"
