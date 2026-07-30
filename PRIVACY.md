# Privacy

LouisMahdi System Inspector is read-only and uses privacy mode by default.

## Network behavior

The application does not automatically connect to the internet, upload reports, send telemetry, run an internet speed test, query a public IP service, download dependencies, check for updates, or transmit collected information.

The GitHub profile opens only after an explicit user click.

## Default redaction

Standard reports redact or omit sensitive identifiers. Extended reports also retain privacy protection unless the user explicitly selects unredacted output.

Privacy mode covers identifiers such as:

- Windows username
- Computer UUID
- BIOS and device serial numbers
- Disk, memory, battery, and monitor serial numbers
- MAC and IP addresses
- Wi-Fi SSID
- Domain information

## Developer diagnostics

Developer diagnostics are disabled by default.

When **Retain developer diagnostics** or `--retain-diagnostics` is enabled, the report package may include provider errors, exception types, stack traces, local file paths, environment-dependent details, or other technical context that is not part of the normal redacted report model.

Review `Developer_Diagnostics.jsonl` before sharing it. Do not publish it until usernames, paths, organization details, network identifiers, and other sensitive information have been removed.

## Unredacted reports

Unredacted output requires Extended mode and an explicit privacy opt-out. Treat an unredacted report as sensitive system information and share it only through a trusted private channel.
