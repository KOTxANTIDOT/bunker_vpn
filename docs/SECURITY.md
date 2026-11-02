# Security model

## Data principles

- Profiles, subscription URLs, UUIDs, passwords, private keys, and tokens are sensitive.
- Keep profile data on-device by default.
- Never include secrets in logs, screenshots, crash reports, test fixtures, or issue reports.
- Do not add telemetry that records destinations, DNS queries, traffic contents, or profile credentials.
- Any optional diagnostics upload must be opt-in, previewable, and redacted.

## Input handling

Subscriptions and imported links are untrusted input. Apply size limits, strict parsing, scheme validation, bounded network timeouts, and safe error handling. Never execute downloaded content as code. Never accept arbitrary engine configuration from a remote subscription unless a future design explicitly defines and validates that format.

## Storage

Use platform-backed secure storage for credentials and sensitive profile fields. Avoid plaintext backups of secrets. Define backup/export behavior explicitly and warn users before exporting credentials.

## Network behavior

- Route DNS according to the active VPN policy.
- Test IPv4, IPv6, DNS, reconnect, and tunnel-failure cases.
- Do not claim leak protection until verified on real devices.
- Fail closed only where the user has explicitly enabled a supported protection mode and Android actually enforces it.

## Android lifecycle

Handle VPN permission revocation, service termination, device reboot, network changes, and process death. Always close TUN descriptors and stop engine resources on every failure path.

## Reporting vulnerabilities

Do not publish working exploit details in public issues. Until a private security contact is configured, report suspected vulnerabilities to the repository owner through a private GitHub security advisory if that feature is available.
