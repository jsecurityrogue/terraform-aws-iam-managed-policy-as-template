terraform-aws-iam-managed-policy-as-template
------------
This accepts input IAM policy, adds SIDs if they don't exist and then, based on the SID override values provided will either replace matching Sid statement, 
or merge in statement as additional statement, and output a merged policy JSON as output.

Example Invocation to override SID "0" in AWS managed Policy arn:aws:iam::aws:policy/PowerUserAccess
------------

```module "iam_merge_poweruser_access" {
    source = "https://github.com/jsecurityrogue/terraform-aws-iam-managed-policy-as-template.git"
    override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
	  override_policy_sid = "0"
	  override_policy_actions = [
	       "iam:*",
	       "organizations:*",
	       "account:*",
	       "sts:*",
	       "kms:*"
	    ]
	override_policy_resources = ["*"]
        override_policy_conditions = [
            {
               test = "StringLike",
               variable = "iam:AWSServiceName",
               values = ["rds.amazonaws.com","cloudwatch.amazonaws.com"],
            },
	    {
               test = "StringNotLike",
               variable = "iam:AWSServiceName",
               values = ["cloudwatch.amazonaws.com"],
            }
         ]
}
```
