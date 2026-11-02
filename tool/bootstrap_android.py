#!/usr/bin/env python3
"""Generate the Android host project and install BUNKER's native sources."""

from pathlib import Path
import shutil
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
ROOT = REPO_ROOT / "app" / "flutter"
ANDROID_DIR = ROOT / "android"
NATIVE_DIR = REPO_ROOT / "native" / "android"
PACKAGE_PATH = Path("app/src/main/kotlin/com/bunkercat/bunker_vpn")
NATIVE_SOURCES = ("MainActivity.kt", "BunkerVpnService.kt")


def install_native_sources() -> None:
    target_dir = ANDROID_DIR / PACKAGE_PATH
    target_dir.mkdir(parents=True, exist_ok=True)

    for filename in NATIVE_SOURCES:
        source = NATIVE_DIR / filename
        if not source.is_file():
            raise FileNotFoundError(f"Missing native Android source: {source}")
        shutil.copy2(source, target_dir / filename)


def patch_manifest() -> None:
    manifest = ANDROID_DIR / "app/src/main/AndroidManifest.xml"
    if not manifest.is_file():
        raise FileNotFoundError(f"Generated Android manifest not found: {manifest}")

    content = manifest.read_text(encoding="utf-8")
    content = content.replace(
        'android:label="bunker_vpn"',
        'android:label="BUNKER VPN"',
    )

    permissions = (
        '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
        '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />',
        '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    )
    for permission in permissions:
        permission_name = permission.split('"')[1]
        if permission_name not in content:
            content = content.replace(
                "<application",
                permission + "\n    <application",
                1,
            )

    service_declaration = """        <service
            android:name="com.bunkercat.bunker_vpn.BunkerVpnService"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:exported="true"
            android:foregroundServiceType="systemExempted">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
        </service>
"""
    if "com.bunkercat.bunker_vpn.BunkerVpnService" not in content:
        content = content.replace("</application>", service_declaration + "    </application>")

    manifest.write_text(content, encoding="utf-8")


def main() -> None:
    if not (ROOT / "pubspec.yaml").is_file():
        raise FileNotFoundError(
            f"Flutter project manifest not found: {ROOT / 'pubspec.yaml'}"
        )

    if not ANDROID_DIR.exists():
        subprocess.run(
            [
                "flutter",
                "create",
                "--platforms=android",
                "--org",
                "com.bunkercat",
                "--project-name",
                "bunker_vpn",
                ".",
            ],
            cwd=ROOT,
            check=True,
        )

    install_native_sources()
    patch_manifest()
    print("Android host is ready. BUNKER native VPN service installed.")


if __name__ == "__main__":
    main()
