# S6 multi-device sync test matrix

Issue: #36

## Automated regression coverage

The automated suite covers the deterministic parts of multi-device synchronization:

- two-peer convergence and incremental second sync;
- interrupted transport and safe resume from updated state vectors;
- three-peer pairwise convergence;
- five-peer coordinator fan-in/fan-out convergence;
- coordinator failover and peer loss;
- reconnect over the encrypted LAN channel;
- deterministic concurrent create/update/delete resolution;
- deterministic field-level last-writer-wins behavior;
- duplicate delivery idempotency and operation/version collision rejection.

The automated checks prove deterministic merge behavior and protocol recovery. They do not replace system testing of mobile lifecycle, radio state, mDNS, or OS background restrictions.

## Manual/system matrix

Run the following on release candidates. Android is required. iOS is required when the signing/device environment is available.

| Scenario | Devices | Required result |
| --- | ---: | --- |
| Basic LAN sync | 2 | Both devices converge to identical transactions, plans, categories, accounts and member state. |
| Coordinator fan-in/fan-out | 3 | All three devices converge after each device creates local changes offline. |
| Large peer set | 5+ | All reachable devices converge; no acknowledged local operation disappears. |
| Same entity, different fields | 2+ | Independent fields survive and final state is identical everywhere. |
| Same field conflict | 2+ | Deterministic LWW result is identical everywhere. |
| Concurrent create/update/delete | 3 | Tombstone/write ordering follows merge rules and converges everywhere. |
| Different entities concurrently | 3+ | No cross-entity contamination; all entities converge independently. |
| Airplane mode during sync | 2 | Session fails safely; after radio restore the next sync resumes without data loss. |
| LAN loss / Wi-Fi change | 2 | Transport disconnect is reported; reconnect resumes from state vectors. |
| Kill coordinator app | 3+ | A surviving device becomes coordinator and remaining peers continue syncing. |
| Kill/restart peer app | 2+ | Restarted peer keeps local journal and catches up after reconnect. |
| Repeated reconnect | 2 | Already acknowledged operations are not duplicated semantically. |
| New device onboarding via snapshot | 2 | New device starts from the snapshot, then receives only newer journal operations and converges. |
| mDNS unavailable | 2 | Manual endpoint path still allows a secure session. |
| Offline changes on every device | 5+ | After reconnection all confirmed local changes are present on every device. |

## Procedure

For every scenario:

1. Record device IDs, OS versions, app build SHA and budget ID.
2. Create a known baseline state and confirm it is identical on all participating devices.
3. Disconnect or alter connectivity as required by the scenario.
4. Perform local mutations and record the expected operations before reconnect.
5. Reconnect and run synchronization until all reachable peers report completion.
6. Compare entity counts and user-visible values on every device.
7. Repeat one additional sync pass and verify there are no unexpected state changes.
8. Export anonymized diagnostics if a mismatch, crash or transport failure is observed.

## Convergence and data-loss acceptance

A scenario passes only when:

- every reachable device reaches the same materialized state;
- every locally confirmed mutation is either present in the converged result or superseded by the documented deterministic conflict rule;
- reconnect does not require deleting local data or recreating the budget;
- no duplicate operation changes the materialized result;
- a failed/interrupted session can be retried safely.

## Snapshot onboarding

For a new device:

1. Create or accept the device membership/invitation.
2. Apply the budget snapshot before normal journal sync.
3. Verify snapshot entities and current member state.
4. Create at least one new mutation on the existing device after the snapshot was created.
5. Run LAN sync.
6. Verify the new device receives only the missing journal tail and reaches the same state.

## Known release limitations

- Automated tests use in-memory/simulated channels for protocol interruption and cannot emulate Android/iOS radio firmware or background execution limits.
- mDNS discovery behavior depends on local network policy; manual endpoint connection is the required fallback.
- iOS device coverage depends on available signing/hardware. If unavailable, record that explicitly in release acceptance rather than treating desktop simulation as iOS evidence.
- The current acceptance evidence must include at least one real Android multi-device run before release.

## Defect handling

Any critical divergence, lost confirmed mutation, unrecoverable reconnect, or coordinator failover failure blocks release. Reproducible merge/protocol defects should receive an automated regression test before the fix is accepted.
