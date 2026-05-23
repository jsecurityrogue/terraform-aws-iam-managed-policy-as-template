terraform {
  required_version = ">= 1.5.7, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.85"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}

module "iam_merge_poweruser_access" {
  source = "../../"

  override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
  override_policy_sid    = "0"
  override_policy_effect = "Allow"

  override_policy_notactions = [
    "iam:*",
    "organizations:*",
    "account:*",
    "sts:*",
    "kms:*",
  ]

  override_policy_resources = ["*"]

  override_policy_conditions = [
    {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  ]
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

output "merged_policy" {
  value = module.iam_merge_poweruser_access.merged_policy
}

output "override_mode" {
  value = module.iam_merge_poweruser_access.override_mode
}

output "source_policy_version" {
  description = "Use this value for approved_policy_version to enable the version gate."
  value       = module.iam_merge_poweruser_access.source_policy_version
}
