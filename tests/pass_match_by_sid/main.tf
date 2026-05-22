terraform {
  required_version = "~> 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "policy" {
  source = "../../"

  override_policy_source     = var.override_policy_source
  override_policy_sid        = var.override_policy_sid
  override_policy_effect     = var.override_policy_effect
  override_policy_actions    = var.override_policy_actions
  override_policy_notactions = var.override_policy_notactions
  override_policy_resources  = var.override_policy_resources
  override_policy_conditions = var.override_policy_conditions
  override_statement_match   = var.override_statement_match
  approved_policy_version    = var.approved_policy_version
}

output "source_policy_arn" {
  value = module.policy.source_policy_arn
}

output "source_policy_name" {
  value = module.policy.source_policy_name
}

output "source_policy_version" {
  description = "Use this to detect if AWS has updated the managed policy since last apply."
  value       = module.policy.source_policy_version
}

output "source_policy_json" {
  value = module.policy.source_policy_json
}

output "merged_policy" {
  value = module.policy.merged_policy
}

output "merged_policy_parsed" {
  value = {
    statement_count = length(jsondecode(module.policy.merged_policy).Statement)
    statement_sids = [
      for s in jsondecode(module.policy.merged_policy).Statement :
      lookup(s, "Sid", "<no sid>")
    ]
  }
}

variable "override_policy_source" {
  type = string
}

variable "override_policy_sid" {
  type = string
}

variable "override_policy_effect" {
  type    = string
  default = "Allow"
}

variable "override_policy_actions" {
  type    = list(string)
  default = null
}

variable "override_policy_notactions" {
  type    = list(string)
  default = null
}

variable "override_policy_resources" {
  type = list(string)
}

variable "override_policy_conditions" {
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []
}

variable "override_statement_match" {
  type    = string
  default = null
}

variable "approved_policy_version" {
  type    = string
  default = null
}
