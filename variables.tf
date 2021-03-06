variable "override_policy_source" {
  type = string
  description = "AWS Managed Policy ARN to override statement block for"
}

variable "override_policy_sid" {
 type = string
 description = "SID value to override.  If you specify unmatched SID, block will be inserted as new block"
}

variable "override_policy_effect" {
 type = string
 description = "Statement Effect value to override.  Defaults to ALLOW."
 default = "Allow"
}

variable "override_policy_actions" {
 type = list(string)
 description = "List of Actions to override in selected SID.  Use only override_policy_actions or override_policy_notactions."
 default = null
}

variable "override_policy_notactions" {
 type = list(string)
 description = "List of NotActions to override in selected SID.  Use only override_policy_actions or override_policy_notactions."
 default = null
}

variable "override_policy_resources" {
  type = list(string)
  description = "List of AWS resources for override block to target"
}

variable "override_policy_conditions" {
  type = list(object({
                 test=string,
                 variable=string,
                 values=list(string)
              })
          )
  description = "Policy Conditions to include in the override block.  Default is no Conditions required."
  default = []
}
