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


def patch_libbox_dependency() -> None:
    """Add the pinned upstream Android libbox artifact to the generated host."""
    settings_candidates = (
        ANDROID_DIR / "settings.gradle.kts",
        ANDROID_DIR / "settings.gradle",
    )
    settings = next((path for path in settings_candidates if path.is_file()), None)
    if settings is None:
        raise FileNotFoundError("Generated Android settings.gradle(.kts) not found")

    settings_content = settings.read_text(encoding="utf-8")
    if "https://jitpack.io" not in settings_content:
        if settings.suffix == ".kts":
            repository = '        maven { url = uri("https://jitpack.io") }\\n'
        else:
            repository = "        maven { url 'https://jitpack.io' }\\n"
        marker = "dependencyResolutionManagement {"
        if marker not in settings_content:
            raise RuntimeError("Could not locate dependencyResolutionManagement in Android settings")
        settings_content = settings_content.replace(
            "repositories {", "repositories {\\n" + repository, 1
        )
        settings.write_text(settings_content, encoding="utf-8")

    app_candidates = (
        ANDROID_DIR / "app/build.gradle.kts",
        ANDROID_DIR / "app/build.gradle",
    )
    app_gradle = next((path for path in app_candidates if path.is_file()), None)
    if app_gradle is None:
        raise FileNotFoundError("Generated Android app build.gradle(.kts) not found")

    app_content = app_gradle.read_text(encoding="utf-8")
    dependency = "com.github.singbox-android:libbox:1.14.4"
    if dependency not in app_content:
        if app_gradle.suffix == ".kts":
            declaration = f'    implementation("{dependency}")\\n'
        else:
            declaration = f"    implementation '{dependency}'\\n"
        if "dependencies {" not in app_content:
            raise RuntimeError("Could not locate dependencies block in Android app Gradle file")
        app_content = app_content.replace("dependencies {", "dependencies {\\n" + declaration, 1)
        app_gradle.write_text(app_content, encoding="utf-8")


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
    patch_libbox_dependency()
    patch_manifest()
    print("Android host is ready. BUNKER native VPN service installed.")


if __name__ == "__main__":
    main()
