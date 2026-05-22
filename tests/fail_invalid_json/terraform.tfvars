# TEST: fail_invalid_json
#
# Verifies that the first variable validation block catches malformed JSON
# in override_statement_match before any AWS API calls are made.
#
# EXPECTED RESULT:
#   - terraform plan FAILS at variable validation
#   - Error message contains:
#     "override_statement_match must be a single JSON statement object if
#      provided, not a full policy document or Statement array."

override_policy_source     = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid        = "PowerUserAccessOverride"
override_policy_effect     = "Allow"
override_policy_resources  = ["*"]
override_policy_notactions = ["iam:*"]
override_policy_conditions = []

# Deliberately malformed JSON — unquoted keys are not valid JSON
override_statement_match = "{ Effect: Allow, NotAction: * }"
