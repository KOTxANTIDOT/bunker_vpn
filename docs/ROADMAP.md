# Roadmap

Status labels: `TODO`, `IN_PROGRESS`, `BLOCKED`, `DONE`. A milestone is not complete because a screen exists; it is complete when its acceptance checks pass.

## M0 — Foundation

- [x] Create a separate public repository.
- [x] Record product principles and initial architecture.
- [x] Record security and licensing requirements.
- [ ] Add source-code license text and complete dependency compatibility audit.
- [x] Add contribution and release-development guidance.

## M1 — Android application skeleton

- [x] Add Flutter application source, package manifest, and initial app version.
- [x] Add Android project bootstrap with application package and display name.
- [x] Add Kotlin bridge source and typed Flutter platform channel.
- [x] Add CI workflow for formatting, static analysis, unit tests, and debug APK build.
- [ ] Pin and verify the supported Flutter/Dart/Android toolchain.
- [ ] Pass CI and produce a downloadable debug APK.
- [ ] Verify app launch and bridge round-trip on a real Android device.

Acceptance: app launches on a real Android device; bridge round-trip works; no VPN connection is claimed.

## M2 — Engine integration

- [ ] Verify official sing-box Android/libbox integration route and supported API.
- [ ] Pin engine version and record upstream commit/release.
- [ ] Build and package engine for supported Android ABIs.
- [ ] Implement adapter start/stop and structured error mapping.
- [ ] Verify TUN descriptor ownership and cleanup.

Acceptance: a controlled test profile can start and stop on a real device without leaked services or descriptors.

## M3 — Profiles and subscriptions

- [ ] Typed profile model and schema version.
- [ ] Import VLESS, VMess, Trojan, Shadowsocks.
- [ ] Subscription fetch, parse, deduplicate, and refresh.
- [ ] Local secure storage for credentials.
- [ ] Import error reporting without exposing secrets.

Acceptance: imported profiles survive restart and invalid input cannot crash the app or start the engine.

## M4 — Routing and DNS

- [ ] DNS policy and leak tests.
- [ ] Per-app include/exclude routing.
- [ ] Domain, IP, and CIDR rules.
- [ ] Direct / proxy / block actions where supported by the engine.
- [ ] Rule precedence and conflict resolution documented.

Acceptance: automated routing tests plus device-level traffic tests prove each rule.

## M5 — User experience and resilience

- [ ] Server list, tags, search, and selection.
- [ ] Reachability/latency testing with timeouts and cancellation.
- [ ] Best-server selection with transparent criteria.
- [ ] Connection state, traffic counters, and diagnostics.
- [ ] Reconnect and boot behavior.
- [ ] Kill Switch validation on supported Android versions.

Acceptance: user-visible states match actual service/engine state; failures recover cleanly.

## M6 — Release readiness

- [ ] Threat model review and dependency audit.
- [ ] DNS/IPv6 leak and regression test suite.
- [ ] Reproducible release workflow and signing procedure.
- [ ] Third-party notices and corresponding source/build instructions.
- [ ] Release notes, known limitations, and support policy.

Acceptance: a clean release build installs, upgrades, connects, disconnects, and passes the release checklist.
