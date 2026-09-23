# 7. CI quality gates

GitHub Actions workflow `.github/workflows/flutter-ci.yml` runs for every push to `main`, every pull request targeting `main`, and manual dispatch.

## Pull request gate

A pull request must pass the `Analyze and test` job.

The job performs these checks in order:

1. installs Flutter dependencies;
2. generates Drift/build_runner code;
3. regenerates code a second time and compares SHA-256 hashes to prove codegen is reproducible;
4. regenerates Drift migration artifacts;
5. generates the migration-test helper from committed schema snapshots;
6. fails if versioned Drift migration artifacts differ from git;
7. checks formatting without modifying source files;
8. runs `flutter analyze`;
9. runs the full Flutter test suite with coverage;
10. publishes an LCOV coverage artifact and a line-coverage summary.

Android is intentionally not built for pull-request events. The same source is built after it reaches `main`, so PR validation avoids spending runner time on an APK that would otherwise be built again after merge.

## Generated files policy

Files such as `*.g.dart` are intentionally ignored by git. CI does not compare them with committed files because there are no committed generated Dart sources.

Instead CI verifies reproducibility:

```text
build_runner
  -> hash generated files
  -> build_runner again
  -> hash generated files again
  -> hashes must match
```

A generator that produces unstable output fails the quality gate.

Drift schema history is different: `drift_schemas/` is versioned and must be committed. CI regenerates migrations and fails when the committed migration history is stale.

## Formatting

CI uses:

```bash
dart format --output=none --set-exit-if-changed lib test
```

It never rewrites source code in CI. A developer must format code before pushing.

## Coverage

Tests run with:

```bash
flutter test --coverage
```

The resulting `coverage/lcov.info` is uploaded as the `flutter-test-coverage` artifact and summarized in the GitHub Actions job summary.

S1 establishes reporting only. A minimum coverage threshold should be introduced later when enough product functionality exists to choose a meaningful baseline.

## Android build

The Android debug APK is built only for pushes to `main` and manual workflow runs.

The build runs at the end of the existing `Analyze and test` job and reuses the same runner, Flutter SDK, dependencies, and generated Dart code. This avoids a second checkout, Flutter setup, `flutter pub get`, and `build_runner` invocation.

This structure keeps pull requests focused on fast correctness checks while still proving that the merged `main` branch produces an Android APK.

Branch-protection rules are repository settings, not application code. The workflow keeps the stable required check name `Analyze and test`.
