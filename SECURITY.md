# Security Policy

## Supported version

Security fixes are provided for the latest published release.

| Version | Supported |
|---|:---:|
| 2.2.x | Yes |
| Earlier versions | No |

## Reporting a vulnerability

Use GitHub private vulnerability reporting when it is available:

https://github.com/TheLouisMahdi/louis-mahdi-system-inspector/security/advisories/new

Do not publish proof-of-concept details, private system reports, usernames, serial numbers, UUIDs, MAC addresses, IP addresses, Wi-Fi names, domain information, or other sensitive identifiers in a public issue.

When private reporting is unavailable, open a minimal public issue that contains no exploit details or sensitive data and asks the maintainer for a private communication channel.

Please include:

- The affected version
- The affected Windows version and architecture
- A concise description of the impact
- Reproduction steps with all personal identifiers removed
- Whether the issue affects the source version, the compiled launcher, or both

## Application behavior

The application is designed to be read-only. It does not change the registry, firmware, TPM, Secure Boot, network configuration, storage configuration, drivers, or operating-system settings.

The application performs no automatic upload, telemetry request, public-IP lookup, dependency download, benchmark, or update check. The GitHub profile opens only after an explicit user action.

## Executable signing

The current public executable is not digitally code-signed. Windows SmartScreen may display an unknown-publisher warning. Download releases only from this repository and verify the published SHA-256 checksum before running the executable.
