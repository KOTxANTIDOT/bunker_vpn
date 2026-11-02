# BUNKER VPN

**An open-source VPN client built from the ground up.**

BUNKER VPN is a new project. It does not fork the old `bunker-cat` application and does not copy code from Throne or other clients.

> **Project status:** Foundation / architecture. No VPN connection functionality is implemented yet.

## Current direction

- **First platform:** Android
- **UI:** Flutter
- **Android integration:** Kotlin + Android `VpnService`
- **Initial network engine:** sing-box, integrated as a third-party component
- **License target:** GPL-3.0-or-later, subject to the dependency/license audit documented in `docs/LICENSING.md`
- **Primary language:** Russian

## Product principles

1. Build a maintainable client, not a collection of unrelated features.
2. Keep the UI, Android tunnel lifecycle, profile model, routing policy, and engine adapter separated.
3. Never invent cryptography or protocol implementations. Use established, audited components.
4. Do not upload profiles, credentials, or traffic metadata without explicit user consent.
5. Make connection state and failures visible and diagnosable.
6. Keep third-party code and licenses clearly attributed.

## Planned capabilities

- Import individual VLESS, VMess, Trojan, and Shadowsocks links.
- Import and refresh subscription URLs.
- Profile list, groups, tags, and manual selection.
- Latency / reachability checks and automatic server selection.
- DNS through the tunnel.
- Per-app routing and domain/IP rules.
- Reconnect, boot handling, and Android Always-on VPN compatibility where supported.
- Kill Switch only after its real behavior has been tested on supported Android versions.
- Diagnostics that do not expose secrets.

## Repository map

```text
app/flutter/          Flutter application (planned)
android/              Kotlin Android host and VpnService (planned)
core/                 Platform-independent domain logic (planned)
engine/               sing-box integration boundary (planned)
docs/                 Architecture, roadmap, security and licensing
```

See:
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Security model](docs/SECURITY.md)
- [Licensing and third-party components](docs/LICENSING.md)
- [Contributing](CONTRIBUTING.md)

## Important

This repository is currently documentation and project scaffolding. Do not treat it as a usable VPN client or installable APK. Features will be marked complete only after implementation and tests.
