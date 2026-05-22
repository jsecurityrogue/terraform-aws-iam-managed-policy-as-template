variable "override_policy_source" {
  type        = string
  description = "AWS Managed Policy ARN to override statement block for. Must be an AWS managed policy (arn:aws:iam::aws:policy/...). Customer-managed policies are not supported."

  validation {
    condition     = can(regex("^arn:aws:iam::aws:policy/", var.override_policy_source))
    error_message = "override_policy_source must be an AWS managed policy ARN (arn:aws:iam::aws:policy/...). Customer-managed policies are not supported."
  }
}

variable "override_policy_sid" {
  type        = string
  description = "SID value to assign to the override statement. If override_statement_match is provided, this SID replaces the matched statement. If neither override_statement_match nor a matching SID is found in the source policy, the statement is appended as a new block."
}

variable "override_policy_effect" {
  type        = string
  description = "Statement Effect value for the override statement. Must be Allow or Deny."
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.override_policy_effect)
    error_message = "override_policy_effect must be Allow or Deny."
  }
}

variable "override_policy_actions" {
  type        = list(string)
  description = "List of Actions for the override statement. Use only one of override_policy_actions or override_policy_notactions, not both."
  default     = null
}

variable "override_policy_notactions" {
  type        = list(string)
  description = "List of NotActions for the override statement. Use only one of override_policy_actions or override_policy_notactions, not both."
  default     = null
}

variable "override_policy_resources" {
  type        = list(string)
  description = "List of AWS resource ARNs the override statement targets. Use [\"*\"] for all resources."
}

variable "override_policy_conditions" {
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  description = "Policy conditions to include in the override statement. Default is no conditions."
  default     = []
}

variable "approved_policy_version" {
  type        = string
  description = <<-EOT
    Optional. The AWS policy version ID (e.g. "v10") that this override has
    been reviewed and approved against. When provided, Terraform will error at
    plan time if the live managed policy version differs — indicating AWS has
    published an update that requires operator review before re-running.

    When null (default), version checking is skipped and the module always
    consumes the current live version of the managed policy. This preserves
    the auto-inherit behavior where new AWS service actions added to the
    managed policy are picked up automatically.

    The current live version ID is always available in the source_policy_version
    output. After reviewing an AWS policy update and confirming the override
    still meets governance requirements, update this value to the new version ID
    to unblock the plan.

    To find the current version ID:
      aws iam get-policy \
        --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
        --query 'Policy.DefaultVersionId' \
        --output text
  EOT
  default     = null
}

variable "override_statement_match" {
  description = <<-EOT
    Optional. A single IAM policy statement object as a JSON string, copied
    directly from the Statement list of the source managed policy. Used to
    locate the exact statement to replace by content match rather than by SID
    or position index.

    Must be a single statement object — not a full policy document and not a
    Statement array. Example of correct input:

    {
      "Sid": "AssumeTaggedRole",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:ResourceTag/Project": "ExampleCorpABC"
        }
      }
    }

    Copy the statement exactly as it appears in the AWS policy JSON.
    The match comparison is exact — do not reformat Resource, Action, or
    NotAction between scalar and list forms from how AWS returns them.

    If the statement cannot be found in the source policy at plan time,
    Terraform will error before applying any changes. This is intentional —
    it indicates the source managed policy has drifted from the expected
    baseline and requires manual review before re-running.

    If omitted, override_policy_sid is used to match by SID instead.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.override_statement_match == null || can(jsondecode(var.override_statement_match))
    error_message = "override_statement_match must be a single JSON statement object if provided, not a full policy document or Statement array. See variable description for an example."
  }

  validation {
    condition = var.override_statement_match == null || (
      can(jsondecode(var.override_statement_match)) &&
      !can(jsondecode(var.override_statement_match).Statement) &&
      can(jsondecode(var.override_statement_match).Effect)
    )
    error_message = "override_statement_match must be a single statement object containing at least an Effect field. A full policy document with a Statement array was provided instead."
  }

  validation {
    condition = var.override_statement_match == null || (
      can(jsondecode(var.override_statement_match)) &&
      can(jsondecode(var.override_statement_match).Resource)
    )
    error_message = "override_statement_match must include a Resource field. Copy the statement exactly as it appears in the AWS policy JSON, including whether Resource is a string or list."
  }
}
