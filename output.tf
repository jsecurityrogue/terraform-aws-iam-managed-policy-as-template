output "source_policy_arn" {
  value       = data.aws_iam_policy.source.arn
  description = "ARN of the original AWS managed policy used as the base."
}

output "source_policy_name" {
  value       = data.aws_iam_policy.source.name
  description = "Name of the original AWS managed policy used as the base."
}

output "source_policy_version" {
  value       = data.aws_iam_policy.source.default_version_id
  description = "Default version ID of the original AWS managed policy. Use this to detect if AWS has updated the managed policy since last apply."
}

output "source_policy_json" {
  value       = data.aws_iam_policy.source.policy
  description = "The original AWS managed policy JSON before any overrides were applied. Preserved in output so operators and CI logs can diff source against merged_policy."
}

output "merged_policy" {
  value       = data.aws_iam_policy_document.override_source.json
  description = "The merged IAM policy JSON with the override statement applied."
}
