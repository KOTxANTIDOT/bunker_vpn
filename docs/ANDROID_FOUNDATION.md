# Android foundation

## Current implementation

The Android app source lives in `app/flutter`. The generated Android Gradle host is created by `tool/bootstrap_android.py`; the script installs the first-party Kotlin sources from `native/android` and patches the generated manifest idempotently.

Native sources:
- `MainActivity.kt`: typed Flutter method channel, Android platform info, VPN permission request, and service start/stop commands.
- `BunkerVpnService.kt`: Android `VpnService` lifecycle, foreground notification, and notification stop action.

## VPN lifecycle bridge

Channel: `vpn.bunker/bridge`

Methods:
- `ping` → `pong`
- `getPlatformInfo` → Android release, SDK level, manufacturer, and device model
- `requestVpnPermission` → launches the Android system VPN consent screen and returns whether permission was granted
- `startVpnService` → starts the foreground VPN service after checking permission
- `stopVpnService` → requests service shutdown
- `getVpnServiceState` → reports the in-process service lifecycle state

The service currently reports `SERVICE_READY_NO_ENGINE`. It deliberately does **not** call `VpnService.Builder.establish()`, because an unconsumed TUN interface would interrupt network traffic. No traffic is routed or protected at this milestone. The UI and notification explicitly communicate that the engine is not connected.

## Next milestone: sing-box engine

Integrate a pinned, reviewed upstream sing-box `libbox` Android build. Implement the platform callbacks and command server/client boundary, pass the established TUN file descriptor to the engine, and only then report Connected. Service teardown must stop the engine before closing the TUN descriptor.

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
