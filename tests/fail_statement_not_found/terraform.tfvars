# TEST: fail_statement_not_found
#
# Verifies that a plan-time error is raised when override_statement_match
# is provided but the statement does not exist in the source policy.
# Simulates the drift detection scenario where AWS has updated the managed
# policy and the baseline statement no longer matches.
#
# EXPECTED RESULT:
#   - terraform plan FAILS
#   - Error message contains:
#     "ERROR: override_statement_match was provided but no matching statement
#      was found in arn:aws:iam::aws:policy/PowerUserAccess."
#   - No changes applied — existing policy assignment remains intact

override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid    = "PowerUserAccessOverride"
override_policy_effect = "Allow"
override_policy_resources  = ["*"]
override_policy_notactions = ["iam:*"]
override_policy_conditions = []

# Structurally valid IAM statement but does not exist in PowerUserAccess.
# The real first statement has no Sid field — adding one here guarantees
# no match, simulating a drifted source policy.
override_statement_match = "{\"Sid\":\"ThisStatementDoesNotExist\",\"Effect\":\"Allow\",\"NotAction\":[\"iam:*\",\"organizations:*\",\"account:*\"],\"Resource\":\"*\"}"
