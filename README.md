# terraform-aws-iam-managed-policy-as-template

Terraform module that fetches an AWS managed IAM policy, applies a statement override, and outputs merged policy JSON. The module is **output-only** — it does not create IAM resources. Wire `merged_policy` into your own `aws_iam_policy`, role attachments, or permission sets.

## What this module does

1. Reads a live AWS managed policy by ARN
2. Normalizes source statements (assigns Sids where missing)
3. Replaces or appends an override statement
4. Outputs merged JSON plus source metadata for governance review

Supported sources: `arn:aws:iam::aws:policy/...` only. Customer-managed policies are not supported.

## Requirements

| Tool | Version |
|------|---------|
| Terraform | `>= 1.5.7, < 2.0.0` (see `.terraform-version`) |
| AWS provider | `~> 5.0` |
| AWSCC provider | `~> 1.85` |

AWS IAM permissions for module use:

- `iam:GetPolicy`
- `iam:GetPolicyVersion`

## Quick start

See [`examples/basic/`](examples/basic/) for a complete root module.

```hcl
module "iam_merge_poweruser_access" {
  source = "github.com/jsecurityrogue/terraform-aws-iam-managed-policy-as-template"

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

output "merged_policy" {
  value = module.iam_merge_poweruser_access.merged_policy
}
```

## Matching modes

| Mode | When | Behavior |
|------|------|----------|
| **Content match** | `override_statement_match` is set | Finds the exact source statement by JSON content and replaces it |
| **SID match** | No content match; Sid exists in source | Override statement replaces the statement with the same Sid |
| **Append** | No content match; Sid not in source | Override statement is appended |

Use `override_mode` and `matched_statement_sid` outputs to confirm which path ran.

## Version gate workflow

When AWS updates a managed policy, new actions may appear automatically. To require manual review before consuming updates:

1. Run a plan and note `source_policy_version` (e.g. `"v10"`)
2. Set `approved_policy_version = "v10"`
3. If AWS publishes a new version, plan fails until you review changes and bump `approved_policy_version`

When `approved_policy_version` is `null` (default), the module always uses the current live version.

Find the current version without Terraform:

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
  --query 'Policy.DefaultVersionId' \
  --output text
```

## Inputs

| Name | Required | Description |
|------|----------|-------------|
| `override_policy_source` | yes | AWS managed policy ARN |
| `override_policy_sid` | yes | Sid for the override statement |
| `override_policy_resources` | yes | Resource ARNs for the override |
| `override_policy_effect` | no | `Allow` or `Deny` (default: `Allow`) |
| `override_policy_actions` | one of | Action allow list for override |
| `override_policy_notactions` | one of | NotAction list for override |
| `override_policy_conditions` | no | Condition blocks for override |
| `override_statement_match` | no | Single statement JSON for content-based replacement |
| `approved_policy_version` | no | Version gate; e.g. `"v10"` |

Exactly one of `override_policy_actions` or `override_policy_notactions` must be set.

## Outputs

| Name | Description |
|------|-------------|
| `merged_policy` | Final merged IAM policy JSON |
| `source_policy_json` | Original managed policy before override |
| `source_policy_arn` | Source policy ARN |
| `source_policy_name` | Source policy name |
| `source_policy_version` | Current default version ID |
| `source_policy_update_date` | Last AWS update timestamp (if available) |
| `override_mode` | `content_match`, `sid_match`, or `append` |
| `matched_statement_sid` | Replaced source Sid, or null if appended |

## Testing

Run locally before tagging a release:

```bash
chmod +x run_tests.sh
make validate    # fmt + terraform validate (no AWS)
make test        # full plan suite against live PowerUserAccess
make simulate    # plan + apply + IAM SimulateCustomPolicy checks
```

Or directly:

```bash
./run_tests.sh
./run_tests.sh --static-only
./run_tests.sh --simulate
```

Test credentials need:

- `iam:GetPolicy`, `iam:GetPolicyVersion` (all non-static runs)
- `iam:SimulateCustomPolicy` (`--simulate` only)

Fixtures live under `tests/<name>/` with `terraform.tfvars` and `expect.json`. Shared harness: `tests/_harness/main.tf`.

### Live policy brittleness

Content-match fixtures embed exact PowerUserAccess statement JSON. When AWS updates that policy, tests fail until you refresh `override_statement_match` in the fixture tfvars. This is intentional drift detection.

Refresh a statement from AWS:

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
  --version-id "$(aws iam get-policy \
    --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
    --query 'Policy.DefaultVersionId' --output text)" \
  --query 'PolicyVersion.Document'
```

### Policy simulation limits

`--simulate` uses `iam:SimulateCustomPolicy` on the generated identity policy. It does **not** model SCPs, permission boundaries, or session policies in your account. Condition keys (e.g. MFA) require explicit context in `simulate.json`.

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).
