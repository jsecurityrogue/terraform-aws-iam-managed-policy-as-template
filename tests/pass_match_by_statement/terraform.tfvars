# TEST: pass_match_by_statement
#
# Verifies that override_statement_match correctly identifies the first
# statement in PowerUserAccess by content and replaces it with the
# override statement containing expanded NotAction list and MFA condition.
#
# Source policy (PowerUserAccess) at time of writing:
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "NotAction": ["iam:*", "organizations:*", "account:*"],
#       "Resource": "*"
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "account:GetAccountInformation",
#         "account:GetGovCloudAccountInformation",
#         "account:GetPrimaryEmail",
#         "account:ListRegions",
#         "iam:CreateServiceLinkedRole",
#         "iam:DeleteServiceLinkedRole",
#         "iam:ListRoles",
#         "organizations:DescribeEffectivePolicy",
#         "organizations:DescribeOrganization"
#       ],
#       "Resource": "*"
#     }
#   ]
# }
#
# EXPECTED RESULT:
#   - terraform plan succeeds
#   - merged_policy contains 2 statements
#   - Statement with SID "PowerUserAccessOverride" has expanded NotAction
#     list (5 entries) and MFA BoolIfExists condition
#   - Second source statement passes through unchanged with SID "1"
#
# To refresh override_statement_match if AWS updates PowerUserAccess:
#   aws iam get-policy-version \
#     --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
#     --version-id $(aws iam get-policy \
#       --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
#       --query 'Policy.DefaultVersionId' --output text) \
#     --query 'PolicyVersion.Document'

override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid    = "PowerUserAccessOverride"
override_policy_effect = "Allow"

override_policy_notactions = [
  "iam:*",
  "organizations:*",
  "account:*",
  "sts:*",
  "kms:*"
]

override_policy_resources = ["*"]

override_policy_conditions = [
  {
    test     = "BoolIfExists"
    variable = "aws:MultiFactorAuthPresent"
    values   = ["true"]
  }
]

# Copied exactly from PowerUserAccess Statement[0].
# No Sid key present in source — do not add one or match will fail.
# Resource is a scalar string "*" in source — do not convert to list.
override_statement_match = "{\"Effect\":\"Allow\",\"NotAction\":[\"iam:*\",\"organizations:*\",\"account:*\"],\"Resource\":\"*\"}"
