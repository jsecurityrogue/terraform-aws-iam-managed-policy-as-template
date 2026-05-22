#!/usr/bin/env bash
# run_tests.sh
# Runs all test fixtures and reports pass/fail.
# Each test directory contains a main.tf and terraform.tfvars.
#
# Usage:
#   chmod +x run_tests.sh
#   ./run_tests.sh
#
# Requirements:
#   - Terraform 1.5.7 on PATH
#   - AWS credentials configured with sufficient permissions to call:
#       iam:GetPolicy
#       iam:GetPolicyVersion

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"
PASS=0
FAIL=0
ERRORS=()

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

run_test() {
  local name="$1"
  local expect="$2"   # "pass" or "fail"
  local dir="$TESTS_DIR/$name"

  echo ""
  echo "─────────────────────────────────────────────"
  echo -e "${YELLOW}TEST:${NC} $name  (expect: $expect)"
  echo "─────────────────────────────────────────────"

  cd "$dir"
  terraform init -backend=false -reconfigure -input=false -no-color > /dev/null 2>&1

  set +e
  terraform plan -var-file=terraform.tfvars -input=false -no-color 2>&1
  local exit_code=$?
  set -e

  if [[ "$expect" == "pass" && $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✓ PASSED${NC} — plan succeeded as expected"
    PASS=$((PASS + 1))
  elif [[ "$expect" == "fail" && $exit_code -ne 0 ]]; then
    echo -e "${GREEN}✓ PASSED${NC} — plan failed as expected"
    PASS=$((PASS + 1))
  elif [[ "$expect" == "pass" && $exit_code -ne 0 ]]; then
    echo -e "${RED}✗ FAILED${NC} — plan was expected to succeed but exited with code $exit_code"
    FAIL=$((FAIL + 1))
    ERRORS+=("$name: expected pass, got fail (exit $exit_code)")
  else
    echo -e "${RED}✗ FAILED${NC} — plan was expected to fail but exited with code 0"
    FAIL=$((FAIL + 1))
    ERRORS+=("$name: expected fail, got pass")
  fi

  cd "$SCRIPT_DIR"
}

echo "============================================="
echo "  IAM Managed Policy Override — Test Suite  "
echo "============================================="

# Pass cases — plan must succeed
run_test "pass_match_by_statement"    "pass"
run_test "pass_match_by_sid"          "pass"
run_test "pass_match_second_statement" "pass"

# Fail cases — plan must error
run_test "fail_statement_not_found"   "fail"
run_test "fail_invalid_json"          "fail"
run_test "fail_full_policy_provided"  "fail"

echo ""
echo "============================================="
echo -e "  Results: ${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}"
echo "============================================="

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for err in "${ERRORS[@]}"; do
    echo -e "  ${RED}•${NC} $err"
  done
  exit 1
fi

exit 0
