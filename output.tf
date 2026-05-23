output "source_policy_arn" {
  value       = data.aws_iam_policy.source.arn
  description = "ARN of the original AWS managed policy used as the base."
}

output "source_policy_name" {
  value       = data.aws_iam_policy.source.name
  description = "Name of the original AWS managed policy used as the base."
}

output "source_policy_version" {
  value       = data.awscc_iam_managed_policy.source_meta.default_version_id
  description = <<-EOT
    Current default version ID of the source managed policy (e.g. "v10").
    Use this as the value for approved_policy_version to enable the version
    gate. If AWS publishes an update the version ID will increment, causing
    version_gate to error at plan time until approved_policy_version is
    updated to the new version ID after operator review.
  EOT
}

output "source_policy_update_date" {
  # update_date is documented as optional in the awscc schema — use try()
  # so the output degrades gracefully to null rather than erroring if the
  # attribute is absent for a given policy.
  value       = try(data.awscc_iam_managed_policy.source_meta.update_date, null)
  description = "Timestamp of the last AWS update to the source managed policy. Null if not available for this policy. Useful context when reviewing whether a version change requires governance re-review."
}

output "source_policy_json" {
  value       = data.aws_iam_policy.source.policy
  description = "The original AWS managed policy JSON before any overrides were applied. Preserved in output so operators and CI logs can diff source against merged_policy."
}

output "merged_policy" {
  value       = data.aws_iam_policy_document.override_source.json
  description = "The merged IAM policy JSON with the override statement applied."
}

output "override_mode" {
  value       = local.override_mode
  description = "How the override statement was applied: content_match (override_statement_match), sid_match (SID collision), or append (new statement)."
}

output "matched_statement_sid" {
  value       = local.matched_statement_sid
  description = "Sid of the source statement that was replaced, or null when the override was appended as a new statement."
}
