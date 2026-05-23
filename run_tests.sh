#!/usr/bin/env bash
# run_tests.sh
# Local verification entry point for this Terraform module.
#
# Usage:
#   ./run_tests.sh                  # fmt, validate, and plan all fixtures
#   ./run_tests.sh --static-only    # fmt and validate only (no AWS calls)
#   ./run_tests.sh --simulate       # plan + apply + IAM policy simulation on pass fixtures
#
# Requirements:
#   - Terraform >= 1.5.7 (see .terraform-version)
#   - jq
#   - AWS CLI (for default and --simulate modes)
#   - AWS credentials with:
#       iam:GetPolicy
#       iam:GetPolicyVersion
#       iam:SimulateCustomPolicy  (--simulate only)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"
HARNESS_DIR="$TESTS_DIR/_harness"
PASS=0
FAIL=0
ERRORS=()

STATIC_ONLY=false
SIMULATE=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  sed -n '2,17p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --static-only)
      STATIC_ONLY=true
      shift
      ;;
    --simulate)
      SIMULATE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${RED}ERROR:${NC} required command not found: $cmd" >&2
    exit 1
  fi
}

record_fail() {
  local message="$1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$message")
}

record_pass() {
  PASS=$((PASS + 1))
}

output_contains() {
  local haystack="$1"
  local needle="$2"
  local normalized_haystack normalized_needle
  normalized_haystack="$(printf '%s' "$haystack" | tr -s '[:space:]' ' ')"
  normalized_needle="$(printf '%s' "$needle" | tr -s '[:space:]' ' ')"
  [[ "$normalized_haystack" == *"$normalized_needle"* ]]
}

run_simulation_cases() {
  local fixture_dir="$1"
  local fixture_name="$2"
  local simulate_file="$fixture_dir/simulate.json"

  [[ -f "$simulate_file" ]] || return 0

  echo "[ simulate ]"

  local merged_policy
  merged_policy="$(terraform output -raw merged_policy)"
  if [[ -z "$merged_policy" ]]; then
    record_fail "$fixture_name: simulate could not read merged_policy output"
    return 1
  fi

  local case_count
  case_count="$(jq 'length' "$simulate_file")"
  local i=0
  while [[ "$i" -lt "$case_count" ]]; do
    local action expected context_entries context_file=""
    action="$(jq -r ".[$i].action" "$simulate_file")"
    expected="$(jq -r ".[$i].expected" "$simulate_file")"

    local -a aws_args=(
      iam simulate-custom-policy
      --policy-input-list "$merged_policy"
      --action-names "$action"
    )

    while IFS= read -r arn; do
      aws_args+=(--resource-arns "$arn")
    done < <(jq -r ".[$i].resource_arns // [\"*\"] | .[]" "$simulate_file")

    context_entries="$(jq -c --argjson idx "$i" '
      .[$idx].context // [] | map({
        ContextKeyName: .key,
        ContextKeyType: .type,
        ContextKeyValues: .values
      })
    ' "$simulate_file")"
    if [[ "$context_entries" != "[]" ]]; then
      context_file="$(mktemp)"
      printf '%s\n' "$context_entries" > "$context_file"
      aws_args+=(--context-entries "file://${context_file}")
    fi

    local sim_output decision
    sim_output="$(aws "${aws_args[@]}" --output json 2>&1)" || {
      [[ -n "$context_file" ]] && rm -f "$context_file"
      record_fail "$fixture_name: simulate-custom-policy failed for $action — $sim_output"
      return 1
    }
    [[ -n "$context_file" ]] && rm -f "$context_file"

    decision="$(echo "$sim_output" | jq -r '.EvaluationResults[0].EvalDecision')"
    if [[ "$decision" != "$expected" ]]; then
      record_fail "$fixture_name: simulate $action expected $expected, got $decision"
      return 1
    fi

    echo "  ✓ $action → $decision"
    i=$((i + 1))
  done

  return 0
}

run_fixture() {
  local fixture_dir="$1"
  local name
  name="$(basename "$fixture_dir")"
  local expect_file="$fixture_dir/expect.json"
  local tfvars_file="$fixture_dir/terraform.tfvars"

  if [[ ! -f "$expect_file" ]]; then
    record_fail "$name: missing expect.json"
    return
  fi

  local expect
  expect="$(jq -r '.expect' "$expect_file")"

  echo ""
  echo "─────────────────────────────────────────────"
  echo -e "${YELLOW}TEST:${NC} $name  (expect: $expect)"
  echo "─────────────────────────────────────────────"

  cd "$HARNESS_DIR"

  echo "[ init ]"
  terraform init -backend=false -reconfigure -input=false -no-color > /dev/null 2>&1
  local init_code=$?
  if [[ "$init_code" -ne 0 ]]; then
    echo -e "${RED}✗ FAILED${NC} — terraform init failed (check provider connectivity)"
    record_fail "$name: terraform init failed"
    cd "$SCRIPT_DIR"
    return
  fi

  echo "[ validate ]"
  terraform validate -no-color > /dev/null 2>&1
  local validate_code=$?
  if [[ "$validate_code" -ne 0 ]]; then
    echo -e "${RED}✗ FAILED${NC} — terraform validate failed"
    record_fail "$name: terraform validate failed"
    cd "$SCRIPT_DIR"
    return
  fi

  if [[ "$STATIC_ONLY" == true ]]; then
    echo -e "${GREEN}✓ PASSED${NC} — static checks succeeded"
    record_pass
    cd "$SCRIPT_DIR"
    return
  fi

  echo "[ plan ]"
  local plan_log
  plan_log="$(mktemp)"
  local exit_code
  terraform plan -lock=false -var-file="$tfvars_file" -input=false -no-color -out="$fixture_dir/tfplan" > "$plan_log" 2>&1
  exit_code=$?
  local plan_output
  plan_output="$(cat "$plan_log")"
  rm -f "$plan_log"

  local result_ok=false
  if [[ "$expect" == "pass" && "$exit_code" -eq 0 ]]; then
    result_ok=true
  elif [[ "$expect" == "fail" && "$exit_code" -ne 0 ]]; then
    result_ok=true
  fi

  if [[ "$result_ok" != true ]]; then
    if [[ "$expect" == "pass" && "$exit_code" -ne 0 ]]; then
      echo -e "${RED}✗ FAILED${NC} — plan was expected to succeed but exited with code $exit_code"
      echo "$plan_output"
      record_fail "$name: expected pass, got fail (exit $exit_code)"
    else
      echo -e "${RED}✗ FAILED${NC} — plan was expected to fail but exited with code 0"
      record_fail "$name: expected fail, got pass"
    fi
    rm -f "$fixture_dir/tfplan"
    cd "$SCRIPT_DIR"
    return
  fi

  local error_count
  error_count="$(jq '.error_contains | length' "$expect_file")"
  if [[ "$expect" == "fail" && "$error_count" -gt 0 ]]; then
    local e=0
    while [[ "$e" -lt "$error_count" ]]; do
      local fragment
      fragment="$(jq -r ".error_contains[$e]" "$expect_file")"
      if ! output_contains "$plan_output" "$fragment"; then
        echo -e "${RED}✗ FAILED${NC} — expected error to contain: $fragment"
        echo "$plan_output"
        record_fail "$name: missing expected error fragment: $fragment"
        rm -f "$fixture_dir/tfplan"
        cd "$SCRIPT_DIR"
        return
      fi
      e=$((e + 1))
    done
  fi

  if [[ "$expect" == "pass" ]]; then
    local expected_count
    expected_count="$(jq -r '.statement_count // empty' "$expect_file")"
    if [[ -n "$expected_count" && -f "$fixture_dir/tfplan" ]]; then
      local actual_count
      actual_count="$(terraform show -json "$fixture_dir/tfplan" | jq -r '.planned_values.outputs.merged_policy_parsed.value.statement_count // empty')"
      if [[ -z "$actual_count" || "$actual_count" != "$expected_count" ]]; then
        echo -e "${RED}✗ FAILED${NC} — expected statement_count $expected_count, got ${actual_count:-<missing>}"
        record_fail "$name: statement_count mismatch"
        rm -f "$fixture_dir/tfplan"
        cd "$SCRIPT_DIR"
        return
      fi
      echo "  statement_count = $actual_count"
    fi
  fi

  if [[ "$SIMULATE" == true && "$expect" == "pass" ]]; then
    echo "[ apply ]"
    terraform apply -lock=false -var-file="$tfvars_file" -input=false -no-color -auto-approve > /dev/null 2>&1
    local apply_code=$?
    if [[ "$apply_code" -ne 0 ]]; then
      record_fail "$name: terraform apply failed during simulation setup"
      rm -f "$fixture_dir/tfplan"
      cd "$SCRIPT_DIR"
      return
    fi

    if ! run_simulation_cases "$fixture_dir" "$name"; then
      rm -f "$fixture_dir/tfplan"
      cd "$SCRIPT_DIR"
      return
    fi
  fi

  rm -f "$fixture_dir/tfplan"

  if [[ "$expect" == "pass" ]]; then
    echo -e "${GREEN}✓ PASSED${NC} — plan succeeded as expected"
  else
    echo -e "${GREEN}✓ PASSED${NC} — plan failed as expected (exit $exit_code)"
  fi
  record_pass
  cd "$SCRIPT_DIR"
}

require_command terraform
require_command jq
if [[ "$STATIC_ONLY" != true ]]; then
  require_command aws
fi

echo "============================================="
echo "  IAM Managed Policy Override — Test Suite  "
echo "============================================="
if [[ "$STATIC_ONLY" == true ]]; then
  echo "Mode: static-only (fmt + validate)"
elif [[ "$SIMULATE" == true ]]; then
  echo "Mode: plan + apply + IAM simulation"
else
  echo "Mode: plan"
fi

echo "[ fmt ]"
if ! terraform fmt -check -recursive -no-color "$SCRIPT_DIR"; then
  echo -e "${RED}✗ FAILED${NC} — terraform fmt check failed (run: terraform fmt -recursive)"
  exit 1
fi
echo -e "${GREEN}✓${NC} formatting OK"

FIXTURES=(
  pass_match_by_statement
  pass_match_by_sid
  pass_match_second_statement
  pass_version_gate_disabled
  fail_statement_not_found
  fail_invalid_json
  fail_full_policy_provided
  fail_version_gate_mismatch
  fail_both_actions_set
  fail_neither_action_set
)

if [[ "$STATIC_ONLY" == true ]]; then
  echo "[ init ]"
  cd "$HARNESS_DIR"
  if ! terraform init -backend=false -reconfigure -input=false -no-color > /dev/null 2>&1; then
    echo -e "${RED}✗ FAILED${NC} — terraform init failed (check provider connectivity)"
    exit 1
  fi

  echo "[ validate ]"
  if ! terraform validate -no-color > /dev/null 2>&1; then
    echo -e "${RED}✗ FAILED${NC} — terraform validate failed"
    exit 1
  fi
  cd "$SCRIPT_DIR"

  for fixture in "${FIXTURES[@]}"; do
    if [[ ! -f "$TESTS_DIR/$fixture/terraform.tfvars" || ! -f "$TESTS_DIR/$fixture/expect.json" ]]; then
      record_fail "$fixture: missing terraform.tfvars or expect.json"
    else
      record_pass
    fi
  done

  echo ""
  echo "============================================="
  echo -e "  Results: ${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}"
  echo "============================================="

  if [[ "${#ERRORS[@]}" -gt 0 ]]; then
    echo ""
    echo "Failures:"
    for err in "${ERRORS[@]}"; do
      echo -e "  ${RED}•${NC} $err"
    done
    exit 1
  fi

  echo -e "${GREEN}✓${NC} static checks OK (${#FIXTURES[@]} fixtures present)"
  exit 0
fi

for fixture in "${FIXTURES[@]}"; do
  run_fixture "$TESTS_DIR/$fixture"
done

echo ""
echo "============================================="
echo -e "  Results: ${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}"
echo "============================================="

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for err in "${ERRORS[@]}"; do
    echo -e "  ${RED}•${NC} $err"
  done
  exit 1
fi

exit 0
