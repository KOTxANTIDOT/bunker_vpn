# BUNKER VPN

**An open-source Android VPN client built from the ground up.**

BUNKER VPN is a new project. It does not fork the old `bunker-cat` application and does not copy code from Throne or other clients.

> **Project status:** Android foundation. The app shell and Flutter-to-Kotlin bridge are in place; VPN tunnel and engine integration are not implemented yet.

## Current direction

- **First platform:** Android
- **UI:** Flutter
- **Android integration:** Kotlin + Android `VpnService`
- **Initial network engine:** sing-box, integrated as a third-party component
- **License target:** GPL-3.0-or-later, subject to the dependency/license audit in `docs/LICENSING.md`
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
app/flutter/                 Flutter application
app/flutter/android/         Generated Android Gradle host (created by bootstrap)
native/android/              Versioned Kotlin bridge source
core/                        Platform-independent domain logic
engine/                      sing-box integration boundary
docs/                        Architecture, roadmap, security and licensing
tool/                        Development/bootstrap scripts
```

## Local build

Requirements: Flutter stable, Android SDK, a supported JDK, and Python 3.

```bash
cd app/flutter
python3 ../../tool/bootstrap_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The Android Gradle host is generated locally by the bootstrap script. CI runs the same setup and publishes a debug APK artifact.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Android foundation](docs/ANDROID_FOUNDATION.md)
- [Roadmap](docs/ROADMAP.md)
- [Security model](docs/SECURITY.md)
- [Licensing and third-party components](docs/LICENSING.md)
- [Contributing](CONTRIBUTING.md)

## Important

The current app shell is not a usable VPN client. It deliberately shows a disconnected state until the real Android VPN service and network engine are integrated and tested.
