# TEST: fail_version_gate_mismatch
#
# Verifies that a plan-time error is raised when approved_policy_version is
# set but does not match the current live version of the managed policy.
# Simulates the scenario where AWS has published an update to the managed
# policy that has not yet been reviewed and approved by the operator.
#
# EXPECTED RESULT:
#   - terraform plan FAILS
#   - Error message contains:
#     "ERROR: arn:aws:iam::aws:policy/PowerUserAccess has been updated by AWS
#      to version <live_version>. Approved version is v1."
#   - No changes applied — existing policy assignment remains intact
#
# NOTE: "v1" is used as the approved version because PowerUserAccess has been
# many times and v1 is guaranteed never to be the current live version.
# The actual current version ID will appear in the error message output,
# which can then be set as approved_policy_version after operator review.



override_policy_source     = "arn:aws:iam::aws:policy/PowerUserAccess"
override_policy_sid        = "PowerUserAccessOverride"
override_policy_effect     = "Allow"
override_policy_resources  = ["*"]
override_policy_notactions = ["iam:*"]
override_policy_conditions = []

# Deliberately stale version — guaranteed to not match current live version
approved_policy_version = "v1"
