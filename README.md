terraform-aws-iam-managed-policy-as-template
------------
This accepts input IAM policy, adds SIDs if they don't exist, then based on the SID override variable provided will either replace matching Sid statement, 
or merge in statement as additional statement, and output a merged policy JSON as output.

Example Invocation to override SID "0" in AWS managed Policy arn:aws:iam::aws:policy/PowerUserAccess
------------

```module "iam_merge_poweruser_access" {
    source = "github.com/jsecurityrogue/terraform-aws-iam-managed-policy-as-template"
    override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
	  override_policy_sid = "0"
	  override_policy_effect = "Allow"
	  override_policy_notactions = [
	       "iam:*",
	       "organizations:*",
	       "account:*",
	       "sts:*",
	       "kms:*"
	    ]
	override_policy_resources = ["*"]
        override_policy_conditions = [
            {
               test = "BoolIfExists",
               variable = "aws:MultiFactorAuthPresent",
               values = ["true"],
            }
         ]
}
```
