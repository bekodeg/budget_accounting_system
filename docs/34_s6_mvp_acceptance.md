# S6 MVP acceptance — FR-01…FR-16

Issue: #38  
Application version reviewed: `0.1.0+2`

## Decision

The implemented MVP is traceable to all functional requirements FR-01…FR-16.

Automated evidence is green for the tested release candidate. The software release itself remains **blocked** until the manual acceptance steps tracked by #36 and #37 are completed:

- real Android multi-device synchronization/lifecycle scenarios;
- installation and smoke test of the signed Android release artifact;
- signed iOS archive/device validation only if Apple signing infrastructure is available.

This document completes the formal requirements review without treating missing physical-device evidence as passed.

## Traceability matrix

| FR | Requirement | Status | Implementation / documentation | Automated evidence | Remaining acceptance |
| --- | --- | --- | --- | --- | --- |
| FR-01 | Create, edit and delete transaction | Implemented | `docs/11_transactions.md` | `transaction_use_cases_test.dart`, `transaction_crud_screen_test.dart`, critical user flow | None beyond release smoke test |
| FR-02 | Income and expense accounting | Implemented | `docs/11_transactions.md`, dashboard/report docs | transaction, dashboard and report repository tests | None |
| FR-03 | Multiple users edit one budget | Implemented | `docs/18_budget_roles.md`, `docs/19_offline_invites.md`, LAN/sync docs | authorization, invitation, sync-session/coordinator tests | Real multi-device run in #36 |
| FR-04 | Monthly plan by category | Implemented | `docs/15_monthly_plans.md` | `monthly_plan_use_cases_test.dart`, `monthly_plan_screen_test.dart` | None |
| FR-05 | Monthly report | Implemented | report architecture/docs | `drift_monthly_report_repository_test.dart`, `monthly_report_screen_test.dart` | None |
| FR-06 | Year report | Implemented | extended report implementation | `drift_extended_report_repository_test.dart`, `extended_reports_screen_test.dart` | None |
| FR-07 | Arbitrary-period report | Implemented | `docs/16_report_export.md` and extended reports | report DAO/repository and presentation tests | None |
| FR-08 | Account/source balance | Implemented | `docs/10_accounts.md` | `account_balance_aggregation_test.dart`, dashboard tests | None |
| FR-09 | Plan remaining = plan − fact | Implemented | monthly-plan/report logic | monthly-plan and report tests | None |
| FR-10 | CSV report export | Implemented | `docs/16_report_export.md` | `export_report_test.dart`, report encoder/temp-file tests | Share-sheet device smoke as part of release smoke |
| FR-11 | XLSX report export | Implemented | `docs/16_report_export.md` | report encoder/export tests | Share-sheet device smoke as part of release smoke |
| FR-12 | Transaction from fiscal QR | Implemented | `docs/24_receipt_qr.md` | QR parser/scanner application + presentation tests | Camera/device smoke recommended |
| FR-13 | Transaction from receipt photo/scan | Implemented | `docs/27_receipt_photo_ocr.md`, `docs/28_receipt_enrichment_provider.md` | photo import/OCR/enrichment tests | Camera/gallery device smoke recommended |
| FR-14 | Work without network | Implemented by architecture | `docs/02_architecture.md`, ADR-001 | local repositories/use cases and offline invite tests | Physical airplane-mode scenario in #36 |
| FR-15 | Sync after connectivity returns | Implemented | `docs/20_lan_p2p.md`, `docs/21_state_vector_sync.md`, `docs/22_sync_coordinator.md`, `docs/23_snapshot_bootstrap.md` | interrupted-session resume, 2/3/5-peer convergence, coordinator failover | Physical network-loss/reconnect scenarios in #36 |
| FR-16 | Author and change-history audit | Implemented at data/sync-journal level | transaction author fields + `sync_operations`, `docs/04_sync_and_conflicts.md` | transaction/sync journal/merge tests | No dedicated end-user audit-history screen in MVP |

## Acceptance notes

### FR-16 audit scope

The MVP records transaction authorship and a signed synchronization operation history sufficient for technical audit and deterministic synchronization.

There is no separate user-facing "change history" screen that renders every historical field change. For the current MVP, FR-16 is accepted at the persisted-data/audit-journal level. If product requirements interpret FR-16 as requiring an end-user history UI, that UI is a post-MVP enhancement rather than an undocumented missing behavior.

### Offline modes

The requirements distinguish:

- **offline isolated** — a device continues local work with no communication channel;
- **offline LAN/P2P** — internet is not required, but peers have a local network path.

Concurrent changes made while isolated use deterministic merge rules when peers reconnect.

### Security and recovery evidence

Release-relevant supporting behavior is also covered by:

- encrypted local database bootstrap;
- encrypted budget backup/restore;
- signed device identity and LAN handshake;
- role-based authorization;
- anonymized diagnostics export;
- snapshot + journal-tail onboarding.

## Automated release evidence

At the time of this acceptance review:

- Stage CI completed successfully on the S6 candidate;
- Performance Baseline completed successfully;
- critical user-flow coverage gate is enabled;
- deterministic 5-device convergence and concurrent conflict regressions are included in the suite.

## Release blockers

The following are not software-development gaps, but required physical-environment acceptance evidence:

1. **#36** — execute the documented multi-device matrix on real Android devices, including airplane mode / process kill / LAN loss.
2. **#37** — install and launch the signed Android APK generated by the release pipeline; verify signed iOS archive only when Apple infrastructure is available.

Until those checks are recorded, the release candidate must not be described as physically device-validated.

## Conclusion

No original FR is silently missing from the implementation traceability review. Automated evidence supports FR-01…FR-16 at the documented MVP scope. The final release decision is intentionally held at the physical-device acceptance gates above.
