# Changelog

## Unreleased

### Added

- Action/NotAction mutual exclusivity validation on override inputs
- Duplicate Sid detection when normalizing source statements (`check "unique_sids"`)
- Terraform `check` blocks for match and version gate (replacing `tobool()` error strings)
- `override_mode` and `matched_statement_sid` outputs
- Shared test harness at `tests/_harness/main.tf`
- `expect.json` per fixture for structured pass/fail assertions
- New fail fixtures: `fail_both_actions_set`, `fail_neither_action_set`
- IAM Policy Simulator integration via `simulate.json` and `./run_tests.sh --simulate`
- `Makefile` with `fmt`, `validate`, `test`, and `simulate` targets
- `examples/basic/` root module
- `.terraform-version` pin for contributors

### Changed

- Relaxed Terraform constraint to `>= 1.5.7, < 2.0.0`
- Split provider requirements into `versions.tf`
- Expanded README with inputs, outputs, testing, and governance workflow
- `run_tests.sh` now runs fmt, validate, plan, optional simulation

## Prior releases (upgrade branch history)

### Added (v2 feature set)

- `override_statement_match` for content-based statement replacement
- `approved_policy_version` version gate with plan-time failure on AWS policy updates
- `source_policy_version` and `source_policy_update_date` outputs
- Integration test suite against live `PowerUserAccess` managed policy

### Changed

- Statement matching uses normalized JSON comparison instead of index-only Sid fallback
- Source policy metadata fetched via `awscc` provider for version ID and update date

## Migration from SID-only usage

If you previously relied only on `override_policy_sid` without `override_statement_match`:

- No input changes required — SID-based replacement still works when the Sid exists in the normalized source policy
- Consider setting `approved_policy_version` after review to detect upstream AWS policy changes
- Consider `override_statement_match` when the source statement has no Sid or you need drift detection on statement content
