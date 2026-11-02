# Licensing and third-party components

## Project license target

The intended license for original BUNKER VPN code is **GNU GPL-3.0-or-later**. The repository must include the complete canonical license text before source-code distribution. Do not assume every dependency can be combined or redistributed under this license without review.

## Initial engine choice

sing-box is the selected initial engine candidate and is distributed under GPL-3.0-or-later. It remains a separately attributed third-party component; BUNKER VPN must not present sing-box as original BUNKER code. Pin an exact release/commit before integration and preserve upstream copyright and license notices.

## Required audit before shipping

For every direct and transitive dependency, record:
- Name, version, source URL, and pinned revision where applicable
- SPDX license identifier and license text location
- Whether source modifications were made
- Required notices, attribution, source-offer, and corresponding-source obligations
- Whether static/dynamic linking or packaging changes the compliance analysis

Flutter packages, AndroidX/Kotlin artifacts, native libraries, build tools, and bundled assets all need review. If a dependency is incompatible or its terms are unclear, replace it or obtain qualified legal review before release.

## Third-party notices

Maintain `THIRD_PARTY_NOTICES.md` and include the relevant license texts in the distributed source/release package. Never remove upstream copyright notices. Never claim endorsement by upstream projects.

## Branding

BUNKER VPN is the product name. Third-party project names and logos remain the property of their respective owners. Do not imply official affiliation or endorsement.
