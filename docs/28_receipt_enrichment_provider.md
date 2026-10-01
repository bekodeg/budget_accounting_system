# Optional receipt enrichment provider

## Contract

Domain and receipt flows depend only on `ReceiptEnrichmentProvider`. A concrete
provider returns normalized merchant/date/total/items and can be replaced
without changing use cases.

## Configuration

Provider enrichment is disabled by default.

Build-time flag:

`--dart-define=RECEIPT_PROVIDER_MODE=mock`

enables the bundled mock adapter used for contract testing and integration
validation. Unknown/disabled modes do not create a provider at all.

## Non-blocking behavior

QR/photo Receipt is persisted locally first. Enrichment is then scheduled as
best-effort background work. Network/auth/rate-limit/provider exceptions are
swallowed by the coordinator and never make the local draft unavailable.

Before applying provider data the coordinator reloads the latest Receipt and
fills only missing fields. Existing local/user-confirmed date, total or merchant
are not overwritten.

Provider-specific raw HTTP responses are not persisted. Only normalized fields,
provider id and optional item labels are merged into parsed_payload.

## Privacy

Receipt images are never passed to the provider contract. The adapter receives
only the already-local Receipt model and can be omitted completely.
