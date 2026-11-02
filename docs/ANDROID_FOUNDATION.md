# Android foundation

## Current implementation

The Android app source lives in `app/flutter`. Android's generated Gradle host project is created by `tool/bootstrap_android.py` using the installed Flutter stable SDK. The Kotlin bridge source is versioned separately in `native/android/MainActivity.kt` and copied into the generated Android host.

This keeps generated Gradle boilerplate out of the initial source commit while preserving the native bridge as first-party source.

## Local setup

Requirements:
- Flutter stable SDK
- Android SDK and an installed Android platform
- Java version supported by the Flutter-generated Gradle project
- Python 3

From the repository root:

```bash
cd app/flutter
python3 ../../tool/bootstrap_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Bridge contract

Channel: `vpn.bunker/bridge`

Methods:
- `ping` → `pong`
- `getPlatformInfo` → Android release, SDK level, manufacturer, and device model

This is a connectivity smoke test only. It does not start a VPN, request VPN permission, create a TUN interface, or claim that traffic is protected.

## Next native milestone

Implement the Android `VpnService` lifecycle, permission flow, foreground notification, and TUN descriptor ownership. Then connect the engine adapter to the verified sing-box Android integration API.
