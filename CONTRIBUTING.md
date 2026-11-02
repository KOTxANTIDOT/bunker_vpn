# Contributing

Thanks for helping build BUNKER VPN.

## Ground rules

- Work in small, reviewable changes.
- Do not copy code from other VPN clients. Use upstream components through documented interfaces and comply with their licenses.
- Do not commit real profiles, subscription URLs, UUIDs, passwords, private keys, tokens, or personal data.
- Add tests for parsers, routing decisions, lifecycle changes, and security-sensitive behavior.
- Keep UI state separate from Android VPN service state.
- Document limitations honestly. A feature is not done until it has tests.

## Before opening a pull request

1. Explain the problem and intended behavior.
2. List the files and architectural areas changed.
3. Run formatting, static analysis, and relevant tests.
4. Include device/API-level details for Android behavior changes.
5. Confirm no secrets or personal data are present.

## Commit style

Use concise imperative messages, for example:
- `docs: define Android service lifecycle`
- `core: validate imported profile schemes`
- `android: add VPN permission bridge`

## Scope

Do not add a second network engine, analytics, remote profile storage, or background telemetry without an architecture/security review.
