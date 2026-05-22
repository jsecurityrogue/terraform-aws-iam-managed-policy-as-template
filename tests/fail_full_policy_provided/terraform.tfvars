# TEST: fail_full_policy_provided
#
# Verifies that the second variable validation block catches a full policy
# document being passed instead of a single statement object. Common mistake
# when copying from the AWS console policy viewer.
#
# EXPECTED RESULT:
#   - terraform plan FAILS at variable validation
#   - Error message contains:
#     "override_statement_match must be a single statement object containing
#      at least an Effect field. A full policy document with a Statement
#      array was provided instead."

override_policy_source     = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid        = "PowerUserAccessOverride"
override_policy_effect     = "Allow"
override_policy_resources  = ["*"]
override_policy_notactions = ["iam:*"]
override_policy_conditions = []

# Full policy document mistakenly provided instead of a single statement.
# The presence of a "Statement" array key triggers the validation failure.
override_statement_match = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"NotAction\":[\"iam:*\",\"organizations:*\",\"account:*\"],\"Resource\":\"*\"}]}"
