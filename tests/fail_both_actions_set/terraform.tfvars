# TEST: fail_both_actions_set
#
# Verifies that setting both override_policy_actions and override_policy_notactions
# fails at plan time via check block before merged policy is produced.
#
# EXPECTED RESULT:
#   - terraform plan FAILS via check block
#   - Error message contains mutual exclusivity guidance

override_policy_source     = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid        = "PowerUserAccessOverride"
override_policy_effect     = "Allow"
override_policy_resources  = ["*"]
override_policy_conditions = []

override_policy_actions = [
  "s3:ListAllMyBuckets"
]

override_policy_notactions = [
  "iam:*"
]
