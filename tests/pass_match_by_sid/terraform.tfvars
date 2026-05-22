# TEST: pass_match_by_sid
#
# Verifies the fallback path where override_statement_match is NOT provided.
# The override statement is matched and replaced by SID value instead.
# Confirms the new statement match logic does not break the original
# SID-based override path.
#
# EXPECTED RESULT:
#   - terraform plan succeeds
#   - merged_policy contains 2 statements
#   - Statement with SID "0" is replaced by the override statement
#     containing expanded NotAction list and MFA condition
#   - Second source statement passes through with SID "1"

override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid    = "0"
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

# override_statement_match intentionally omitted — exercises SID fallback path
