# terraform-aws-iam-managed-policy-as-template

Accepts an AWS managed IAM policy by ARN, assigns position-based SIDs to any statements that lack them, then either replaces the matching statement or merges in a new statement — outputting the result as a merged policy JSON.

Designed specifically for AWS job function managed policies (e.g. `PowerUserAccess`, `ReadOnlyAccess`) that AWS maintains and updates over time. Rather than forking a policy into a customer-managed copy and owning the maintenance burden, this module lets you ride AWS updates automatically while enforcing a single governance carve-out.

> **Scope:** This module targets AWS managed policies only (`arn:aws:iam::aws:policy/...`). Customer-managed policies, resource-based policies, and trust policies are not supported.

---

## How It Works

1. Fetches the source managed policy JSON from AWS
2. Assigns SIDs to any statements that lack them (using zero-based position index as fallback)
3. Reconstructs the policy in HCL so Terraform can work with it natively
4. Merges in the override statement — replacing any existing statement with a matching SID, or appending as a new statement if no match is found
5. Outputs the merged policy JSON

---

## Example: Harden PowerUserAccess

`PowerUserAccess` uses a `NotAction` pattern to allow everything except `iam:*`, `organizations:*`, and `account:*`. This example replaces that statement with a tighter version that additionally excludes `sts:*` and `kms:*`, and enforces MFA.

The override uses `Allow` + `NotAction` rather than an explicit `Deny` — this creates an implicit deny on the excluded actions, which allows more targeted roles to still grant specific actions like `sts:AssumeRole` or `sts:PassRole` where operationally justified. An explicit `Deny` would block those grants unconditionally.

```hcl
module "iam_merge_poweruser_access" {
  source = "github.com/jsecurityrogue/terraform-aws-iam-managed-policy-as-template"

  override_policy_source = "arn:aws:iam::aws:policy/PowerUserAccess"
  override_policy_sid    = "PowerUserAccessOverride"
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
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  ]
}
```

---

## Statement Matching

The module supports two ways to identify which statement to replace:

### Match by SID

If the source policy has explicit SIDs, set `override_policy_sid` to the SID you want to replace. For policies without SIDs (like `PowerUserAccess`), statements are assigned position-based SIDs (`"0"`, `"1"`, ...) which can be targeted the same way.

```hcl
override_policy_sid = "0"  # targets the first statement by position
```

This is simple but fragile — if AWS reorders statements in a future policy update, position-based targeting silently hits the wrong statement.

### Match by Statement Content (Recommended)

Provide the exact source statement as JSON via `override_statement_match`. The module finds it by content comparison and replaces it, regardless of its position in the policy.

```hcl
override_statement_match = jsonencode({
  "Effect"    = "Allow"
  "NotAction" = ["iam:*", "organizations:*", "account:*"]
  "Resource"  = "*"
})
```

> **Important:** Copy the statement exactly as AWS returns it. The match comparison is exact — do not reformat `Resource`, `Action`, or `NotAction` between scalar and list forms from how AWS returns them. If the statement is not found, Terraform will error at plan time before making any changes.

---

## Version Gate

To prevent AWS policy updates from silently affecting your override, enable the version gate by setting `approved_policy_version` to the current policy version ID. Terraform will error at plan time if the live policy version has changed, requiring operator review before re-running.

```hcl
module "iam_merge_poweruser_access" {
  source = "github.com/jsecurityrogue/terraform-aws-iam-managed-policy-as-template"

  override_policy_source  = "arn:aws:iam::aws:policy/PowerUserAccess"
  approved_policy_version = "v10"   # from source_policy_version output

  # ... other variables
}
```

When the gate fires you will see:

```
ERROR: arn:aws:iam::aws:policy/PowerUserAccess has been updated by AWS to
version v11 (2025-03-15T10:22:00Z). Approved version is v10. Review the
policy changes, confirm the override still meets governance requirements,
then update approved_policy_version to v11 to unblock the plan.
```

To find the current version ID without running a plan:

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
  --query 'Policy.DefaultVersionId' \
  --output text
```

Omitting `approved_policy_version` (the default) disables the gate and the module always inherits the current live policy — which is appropriate for teams that want automatic adoption of new AWS service actions without governance review overhead.

---

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `override_policy_source` | `string` | yes | — | ARN of the AWS managed policy to use as the base. Must match `arn:aws:iam::aws:policy/...` |
| `override_policy_sid` | `string` | yes | — | SID to assign to the override statement. Replaces a matching SID in the source, or appends as a new statement if no match |
| `override_policy_effect` | `string` | no | `"Allow"` | Effect for the override statement. Must be `Allow` or `Deny` |
| `override_policy_actions` | `list(string)` | no | `null` | Actions for the override statement. Mutually exclusive with `override_policy_notactions` |
| `override_policy_notactions` | `list(string)` | no | `null` | NotActions for the override statement. Mutually exclusive with `override_policy_actions` |
| `override_policy_resources` | `list(string)` | yes | — | Resource ARNs the override statement targets. Use `["*"]` for all resources |
| `override_policy_conditions` | `list(object)` | no | `[]` | Conditions to include in the override statement. See [Conditions](#conditions) |
| `override_statement_match` | `string` | no | `null` | JSON string of the exact source statement to find and replace by content. See [Statement Matching](#statement-matching) |
| `approved_policy_version` | `string` | no | `null` | Policy version ID approved for use. Enables the version gate when set. See [Version Gate](#version-gate) |

### Conditions

The `override_policy_conditions` variable accepts a list of objects with the following fields:

```hcl
override_policy_conditions = [
  {
    test     = "BoolIfExists"           # IAM condition operator
    variable = "aws:MultiFactorAuthPresent"
    values   = ["true"]
  }
]
```

---

## Outputs

| Name | Description |
|---|---|
| `merged_policy` | The merged IAM policy JSON with the override statement applied. Pass to `aws_iam_policy` or `aws_iam_role_policy` |
| `source_policy_json` | The original managed policy JSON before any overrides. Use to diff against `merged_policy` in CI logs |
| `source_policy_version` | Current default version ID of the source policy (e.g. `"v10"`). Use as `approved_policy_version` to enable the version gate |
| `source_policy_update_date` | Timestamp of the last AWS update to the source policy. `null` if not available for this policy |
| `source_policy_arn` | ARN of the source managed policy |
| `source_policy_name` | Name of the source managed policy |

---

## Requirements

| Name | Version |
|---|---|
| Terraform | `~> 1.5.7` |
| AWS provider (`hashicorp/aws`) | `~> 5.0` |
| AWSCC provider (`hashicorp/awscc`) | `~> 1.85` |

Both providers use the standard AWS credential chain. If your environment uses a named profile or role assumption, configure both providers consistently:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "my-profile"
}

provider "awscc" {
  region  = "us-east-1"
  profile = "my-profile"
}
```

---

## Testing

The module includes a test suite under `tests/` that verifies both pass and fail cases against the live AWS API. Tests require Terraform 1.5.7 and AWS credentials with `iam:GetPolicy` and `iam:GetPolicyVersion` permissions.

```bash
cd terraform-aws-iam-managed-policy-as-template
chmod +x run_tests.sh
./run_tests.sh
```

### Test Cases

| Test | Expects | Verifies |
|---|---|---|
| `pass_match_by_statement` | Plan succeeds | First statement matched by content, replaced with expanded `NotAction` and MFA condition |
| `pass_match_by_sid` | Plan succeeds | SID position fallback path (`"0"`) works independently of content matching |
| `pass_match_second_statement` | Plan succeeds | Second statement matched by content, `Action` list code path |
| `pass_version_gate_disabled` | Plan succeeds | `approved_policy_version = null` skips version check entirely |
| `fail_statement_not_found` | Plan errors | Content match fails when statement does not exist in source policy (drift detection) |
| `fail_invalid_json` | Validation error | Malformed JSON in `override_statement_match` caught before AWS API call |
| `fail_full_policy_provided` | Validation error | Full policy document passed instead of single statement |
| `fail_version_gate_mismatch` | Plan errors | Stale `approved_policy_version` blocks plan until operator reviews and updates |

### Refreshing Test Fixtures

The `pass_match_by_statement` and `pass_match_second_statement` fixtures contain hardcoded statement JSON copied from `PowerUserAccess`. If AWS updates this policy the content match will fail — which is intentional, as it is exactly the drift detection behavior the module is designed to surface.

To refresh the fixtures after an AWS policy update:

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
  --version-id $(aws iam get-policy \
    --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
    --query 'Policy.DefaultVersionId' \
    --output text) \
  --query 'PolicyVersion.Document' \
  --output text
```

Copy the updated statement JSON into the `override_statement_match` value in the relevant `terraform.tfvars` file, then re-run the test suite to confirm.

---

## Design Notes

**Why not fork the managed policy?** AWS updates job function managed policies when new services and actions are released. A forked customer-managed copy requires manual maintenance to stay current. This module lets you inherit updates automatically while enforcing your single governance carve-out.

**Why does the version gate use a version ID rather than a content hash?** Version IDs (`v10`, `v11`) are human-readable and directly correspond to what you see in the AWS console and CLI. They make the approval workflow explicit — an operator can look up what changed between versions and record the review decision against a meaningful identifier.
