variable "override_policy_source" {
  type = string
  description = "AWS Managed Policy ARN to override statement block for"
}

variable "override_policy_sid" {
 type = string
 description = "SID value to override.  If you specify unmatched SID, block will be inserted as new block"
}

variable "override_policy_actions" {
 type = list(string)
 description = "List of Actions to override in selected SID"
 default = null
}

variable "override_policy_notactions" {
 type = list(string)
 description = "List of NotActions to override in selected SID"
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
  description = "Policy Conditions to include in the override block"
  default = []
}
