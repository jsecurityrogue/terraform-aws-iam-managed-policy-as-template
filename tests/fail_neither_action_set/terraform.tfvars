# TEST: fail_neither_action_set
#
# Verifies that omitting both override_policy_actions and override_policy_notactions
# fails at plan time via check block.
#
# EXPECTED RESULT:
#   - terraform plan FAILS via check block
#   - Error message requires one of the action fields

override_policy_source     = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid        = "PowerUserAccessOverride"
override_policy_effect     = "Allow"
override_policy_resources  = ["*"]
override_policy_conditions = []
