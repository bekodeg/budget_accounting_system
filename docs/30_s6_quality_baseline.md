# S6 quality baseline

Issue: #34

## Critical automated flows

The release gate must keep automated coverage for the highest-risk local-first flows:

- onboarding and initial budget creation;
- account and category creation;
- income and expense creation;
- monthly planning;
- report consumption;
- transaction soft delete;
- OWNER / EDITOR / VIEWER permission matrix;
- deterministic merge and simulated peer synchronization, including interrupted sessions.

The existing focused unit/widget tests remain the preferred place for detailed edge cases.
`test/application/critical_user_flow_test.dart` adds a compact cross-use-case regression path so incompatible changes between otherwise well-tested use cases are detected before release.

## Coverage baseline

Stage CI produces `coverage/lcov.info` and now enforces a minimum line coverage baseline through `tool/check_coverage.sh`.

Initial floor: **35.00% line coverage**.

This value is intentionally a floor, not a quality target. It is meant to prevent accidental large regressions while S6 expands scenario coverage. The baseline should only move upward after a green Stage run demonstrates the new sustained level. Lowering it requires an explicit change to this document and CI.

### Exclusions

Generated sources are not used as a reason to add tests. Coverage should focus on handwritten application/domain/data/presentation behavior. Platform-generated Android/iOS host files and generated Drift/build-runner output are outside the baseline intent.

## Flakiness policy

Tests in the release gate must be deterministic. A flaky test is treated as a defect: fix or quarantine it with a linked issue before promotion to `stage`.
