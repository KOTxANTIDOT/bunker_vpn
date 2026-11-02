# Architecture

## Goals

BUNKER VPN is a new Android-first client with clear boundaries between the interface, platform tunnel, profile/routing domain, and network engine. The initial implementation is deliberately single-engine: sing-box. Adding a second engine before the first integration is stable would multiply lifecycle, configuration, testing, and support work.

## High-level flow

```text
Flutter UI
   | typed commands / state events
Kotlin bridge
   |
Android VpnService + TUN file descriptor
   |
Engine adapter (libbox boundary)
   |
sing-box
   |-- outbound protocols
   |-- DNS
   |-- routing
   |-- connection lifecycle
Network
```

### Flutter

Owns screens, navigation, presentation state, profile editing, subscription UX, and user preferences. It must not own the Android TUN lifecycle or implement VPN protocols.

### Kotlin Android host

Owns Android-specific permissions, `VpnService`, foreground notification, TUN descriptor lifecycle, process/service lifecycle, and the typed bridge to Flutter. It reports actual engine/service state; the UI must not assume a connection succeeded merely because a button was pressed.

### Core domain

Platform-independent models and use cases:
- Profile and subscription models
- Import parsing and validation
- Routing rules and app-selection policy
- Server test results and selection policy
- Redacted diagnostics

Core logic should be testable without Android or a running VPN.

### Engine adapter

A narrow boundary around the selected sing-box integration. It translates validated domain configuration into engine configuration, starts/stops the engine, forwards state and statistics, and normalizes errors. Engine-specific types must not leak into Flutter screens.

### sing-box

Third-party networking engine. It is not BUNKER VPN's own implementation. Pin a reviewed version, preserve its notices, track upstream changes, and document build/release steps. Do not copy code from other VPN clients.

## Repository layout

```text
app/flutter/                 Flutter UI, app services and Dart tests
app/flutter/android/         Generated Android Gradle host (bootstrap output)
native/android/              Versioned first-party Kotlin bridge/service sources
core/profiles/               Profile models and import
core/subscriptions/          Subscription parsing and refresh
core/routing/                Routing policy and rule evaluation
core/diagnostics/            Redacted diagnostics
engine/sing-box/             Pinned engine integration
docs/                        Project documentation
tool/                        Development and bootstrap scripts
.github/workflows/           CI workflows
```

The exact native source layout may change after the official sing-box Android integration API is verified. Generated Gradle files are created by `tool/bootstrap_android.py`; first-party Kotlin source remains versioned under `native/android/`.

## Connection lifecycle

1. User selects Connect.
2. Android host requests VPN permission when required.
3. The app validates the selected profile and routing configuration.
4. Kotlin starts the foreground VPN service and obtains the TUN descriptor.
5. The engine adapter starts sing-box with the TUN descriptor and validated configuration.
6. The host reports Connected only after the engine reports a successful start.
7. Disconnect, service stop, process death, and errors all converge on safe cleanup.
8. UI receives a final state and a redacted error reason.

Every transition must be idempotent. Repeated Connect/Disconnect events must not create duplicate services or leak descriptors.

## Configuration rules

- Build engine configuration from typed internal models; do not concatenate untrusted JSON.
- Validate imported links and subscription content before saving or starting.
- Keep credentials out of logs, crash reports, and analytics.
- Store secrets using Android-backed secure storage where appropriate.
- Version the internal profile schema and provide migrations.
- Treat subscription content as untrusted input.

## Testing boundaries

- Unit tests: parsers, validation, routing policy, server selection.
- Android tests: permission flow, service lifecycle, TUN cleanup, notification.
- Engine integration tests: start/stop, DNS, representative protocols, invalid configuration.
- Device matrix: supported Android versions and at least one real device from each supported API range.
- Leak checks: DNS and IPv6 behavior, including reconnect and failure cases.
