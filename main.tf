# ---------------------------------------------------------------------------
# Fetch the source AWS managed policy content (JSON) via the aws provider
# ---------------------------------------------------------------------------
data "aws_iam_policy" "source" {
  arn = var.override_policy_source
}

# ---------------------------------------------------------------------------
# Fetch the source AWS managed policy metadata via the awscc provider.
# The awscc data source exposes default_version_id and update_date which
# are not available on the aws provider's aws_iam_policy data source.
# ---------------------------------------------------------------------------
data "awscc_iam_managed_policy" "source_meta" {
  id = var.override_policy_source
}

locals {
  # Decode once — avoids repeated jsondecode calls throughout
  source_policy_decoded = jsondecode(data.aws_iam_policy.source.policy)

  # Parse the match statement once if provided
  match_statement = var.override_statement_match != null ? jsondecode(var.override_statement_match) : null

  # ---------------------------------------------------------------------------
  # Normalize both sides to compact sorted-key JSON for reliable comparison.
  # The round-trip through jsondecode/jsonencode handles:
  #   - Key ordering differences
  #   - Whitespace and formatting differences
  # Users must still copy Resource/Action/NotAction exactly as AWS returns them
  # (scalar vs list) since AWS does not normalize these on save.
  # ---------------------------------------------------------------------------
  normalized_source_statements = [
    for s in local.source_policy_decoded.Statement :
    jsonencode(jsondecode(jsonencode(s)))
  ]

  normalized_match = var.override_statement_match != null ? jsonencode(jsondecode(jsonencode(local.match_statement))) : null

  # ---------------------------------------------------------------------------
  # Safe match check using contains() — does not throw on no match unlike index()
  # ---------------------------------------------------------------------------
  match_found = var.override_statement_match != null ? contains(local.normalized_source_statements, local.normalized_match) : true

  # Only evaluated after contains() confirms match exists — safe from index() throw
  matched_index = local.match_found && var.override_statement_match != null ? index(local.normalized_source_statements, local.normalized_match) : -1

  # ---------------------------------------------------------------------------
  # Reshape each source statement into a known structure for dynamic block use.
  # Handles:
  #   - Missing Sid (falls back to matched override SID or position index)
  #   - Action vs NotAction (mutually exclusive in IAM)
  #   - Condition blocks (nested map shape flattened to list)
  #
  # Note: Principal/NotPrincipal are intentionally not handled here.
  # data.aws_iam_policy fetches IAM managed policies only, which never
  # contain Principal blocks — those are only valid in resource-based
  # and trust policies, which use different data sources entirely.
  # ---------------------------------------------------------------------------
  statements = flatten([
    for idx, statement in local.source_policy_decoded.Statement : {
      Sid = lookup(statement, "Sid",
        idx == local.matched_index ? var.override_policy_sid : tostring(idx)
      )
      Effect    = statement.Effect
      Resource  = try(tolist(statement.Resource), [tostring(statement.Resource)])
      Action    = lookup(statement, "Action", null)
      NotAction = lookup(statement, "NotAction", null)
      Condition = flatten([
        for test, condition_map in lookup(statement, "Condition", {}) : [
          for variable, values in condition_map : {
            Test     = test
            Variable = variable
            Values   = try(tolist(values), [tostring(values)])
          }
        ]
      ])
    }
  ])

  # ---------------------------------------------------------------------------
  # Index the statements as a map keyed by Sid for for_each compatibility.
  # for_each on a dynamic block requires a map or set — tuples and lists are
  # not accepted. Keying by Sid also makes plan output more readable since
  # Terraform uses the key as the resource address.
  # ---------------------------------------------------------------------------
  statements_map = {
    for idx, s in local.statements : s.Sid => s
  }

  duplicate_sids = length(local.statements) != length(keys(local.statements_map))

  override_mode = (
    var.override_statement_match != null ? "content_match" :
    contains(keys(local.statements_map), var.override_policy_sid) ? "sid_match" :
    "append"
  )

  matched_statement_sid = (
    var.override_statement_match != null && local.matched_index >= 0 ? local.statements[local.matched_index].Sid :
    contains(keys(local.statements_map), var.override_policy_sid) ? var.override_policy_sid :
    null
  )
}

# ---------------------------------------------------------------------------
# Intermediate step: reconstruct the fetched managed policy in HCL so
# Terraform can consume it as a source_policy_document. Required because
# aws_iam_policy_document does not accept raw JSON as a source directly.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "source_normalized" {
  dynamic "statement" {
    for_each = local.statements_map

    content {
      sid       = statement.value["Sid"]
      effect    = statement.value["Effect"]
      resources = statement.value["Resource"]

      actions     = statement.value["Action"] != null ? try(tolist(statement.value["Action"]), [tostring(statement.value["Action"])]) : null
      not_actions = statement.value["NotAction"] != null ? try(tolist(statement.value["NotAction"]), [tostring(statement.value["NotAction"])]) : null

      dynamic "condition" {
        for_each = statement.value["Condition"]

        content {
          test     = condition.value["Test"]
          variable = condition.value["Variable"]
          values   = condition.value["Values"]
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Final merged policy: normalized source policy with the override statement.
# The override statement replaces the matched statement via SID collision,
# or is appended as a new statement if no SID match exists.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "override_source" {
  source_policy_documents = [data.aws_iam_policy_document.source_normalized.json]

  statement {
    sid       = var.override_policy_sid
    effect    = var.override_policy_effect
    resources = var.override_policy_resources

    actions     = var.override_policy_actions != null ? var.override_policy_actions : null
    not_actions = var.override_policy_notactions != null ? var.override_policy_notactions : null

    dynamic "condition" {
      for_each = var.override_policy_conditions

      content {
        test     = condition.value["test"]
        variable = condition.value["variable"]
        values   = condition.value["values"]
      }
    }
  }
}
