# Plan-time input guards. Uses terraform_data (no AWS resources) so invalid
# module input fails terraform plan with a non-zero exit code. Check blocks
# only warn during plan, which is insufficient for an output-only module.
resource "terraform_data" "plan_guards" {
  lifecycle {
    precondition {
      condition     = !(var.override_policy_actions != null && var.override_policy_notactions != null)
      error_message = "Set exactly one of override_policy_actions or override_policy_notactions, not both."
    }

    precondition {
      condition     = var.override_policy_actions != null || var.override_policy_notactions != null
      error_message = "One of override_policy_actions or override_policy_notactions must be set."
    }

    precondition {
      condition     = var.override_statement_match == null || local.match_found
      error_message = "override_statement_match was provided but no matching statement was found in ${var.override_policy_source}. The source managed policy may have changed from the expected baseline. Review the policy in the AWS console before re-running."
    }

    precondition {
      condition = (
        var.approved_policy_version == null ||
        var.approved_policy_version == data.awscc_iam_managed_policy.source_meta.default_version_id
      )
      error_message = "${var.override_policy_source} has been updated by AWS to version ${data.awscc_iam_managed_policy.source_meta.default_version_id}${try(" (${data.awscc_iam_managed_policy.source_meta.update_date})", "")}. Approved version is ${coalesce(var.approved_policy_version, "(not set)")}. Review the policy changes, confirm the override still meets governance requirements, then update approved_policy_version to ${data.awscc_iam_managed_policy.source_meta.default_version_id} to unblock the plan."
    }

    precondition {
      condition     = !local.duplicate_sids
      error_message = "Duplicate Sid values detected when normalizing ${var.override_policy_source}. Statements with colliding Sids would be silently dropped. Review the source policy in the AWS console."
    }
  }
}
