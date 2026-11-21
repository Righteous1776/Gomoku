# ECLIPSE Thinking HUD — Stage D1 measured latency & thermal pressure

Stacked on Issue #50 Stage C1, pending Stage B/C native/iOS gates. **Not a full Stage D acceptance.**

## What is actually measured

- A completed, successfully attested native C++20 V2 decision contributes its exact `GomokuBotMove.elapsedMilliseconds` to an in-memory window of 128 latency samples.
- Each window uses an exact composite key `active compiled checkpoint SHA-256 + approved compute-policy SHA-256`. Swift fallback, unverifiable model identity, interrupted/cancelled native searches and legal-move emergency fallbacks are never included.
- The developer HUD displays P50/P95 using nearest-rank quantiles **only after 20 valid completed turns** of the same native model and policy. Missing or sparse data is labeled insufficient, not zero.
- Device thermal status comes directly from `ProcessInfo.processInfo.thermalState`, i.e. OS thermal *pressure category*, NOT CPU/GPU temperature in Celsius. Low Power Mode is read from `ProcessInfo` directly. No other private app data is collected.
- Data is ephemeral and bounded (16 signatures × 128 samples); not attached to personal match logs, transmitted, or presented as a cross-device benchmark.

## Not yet measurable or independently accepted

- Physical-device P95 UI frame latency, CPU share, resident/peak memory, thermal sensor temperature, per-turn joules and hardware throttling traces: no measured values claimed.
- Sol resource fallback must be proved with a genuine load/execute failure, unchanged board replay, preserved SHA/model attribution and tactical regression tests. This patch does **not** switch models.
- More than 20 samples and controlled matched hardware are required before comparing Astra/Sol latency across versions.
- R17 original card/board styles and search decisions must stay intact. Screenshot and iOS XCTest/VoiceOver tests are mandatory before merging. No release or merge authorization.

## Tests

`EclipseThinkingHUDTests.testNativeP50P95UsesRealSamePolicySamplesAndMinimumTwenty` guards against small-sample percentile misuse, fake zero samples and wrong nearest-rank math. The native Stage B CTest and original UI contract remain mandatory.
