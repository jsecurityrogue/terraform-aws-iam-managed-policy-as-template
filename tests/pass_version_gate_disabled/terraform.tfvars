# TEST: pass_version_gate_disabled
#
# Verifies that omitting approved_policy_version (null default) skips the
# version check entirely and the plan succeeds regardless of the current
# live policy version. This is the auto-inherit path for teams that do not
# require explicit version approval.
#
# EXPECTED RESULT:
#   - terraform plan succeeds
#   - source_policy_version output shows the current live version ID
#   - No version mismatch error regardless of what AWS version is live

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

# approved_policy_version intentionally omitted — exercises null/skip path
