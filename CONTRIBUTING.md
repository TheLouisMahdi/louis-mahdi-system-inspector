# Contributing

Thank you for helping improve LouisMahdi System Inspector.

## Before opening an issue

- Check the latest release and existing issues.
- Remove usernames, serial numbers, UUIDs, MAC addresses, IP addresses, Wi-Fi names, domain details, and other identifiers from logs or reports.
- Confirm whether the issue occurs in Standard mode, Extended mode, or both.
- State whether the application was started from source or from the released EXE.

## Development requirements

- Windows 10, Windows 11, or Windows Server 2016 or later
- Windows PowerShell 5.1
- The built-in .NET Framework C# compiler used by the project builder
- Git

## Validation

Run the validation scripts before submitting a change:

```powershell
.\tests\Validate-Source.ps1 -SourcePath .\src\LouisMahdi.SystemInspector.ps1
.\tests\Validate-Launcher.ps1 -LauncherPath .\docs\LouisMahdiHost.cs -BuilderPath .\Build_LouisMahdi_System_Inspector_ONE_FILE.bat
.\tests\Run-MockTests.ps1
```

You may also run:

```text
Run_Tests.bat
```

For a complete build and launcher self-test:

```text
Build_LouisMahdi_System_Inspector_ONE_FILE.bat
```

## Code expectations

- Keep production code and user-facing technical text in English.
- Preserve Windows PowerShell 5.1 compatibility.
- Keep collection read-only and offline.
- Do not add telemetry, automatic uploads, dependency downloads, benchmarks, update checks, or public-IP lookups.
- Preserve privacy mode as the default.
- Preserve explicit unavailable, unsupported, permission-denied, invalid, disconnected, inferred, and redacted states.
- Do not present inferred values as directly reported values.
- Add or update mock tests for behavior changes.
- Update the changelog, release notes, version metadata, sample reports, and documentation when a public contract changes.

## Pull requests

A pull request should contain:

- A focused description of the change
- The Windows versions and architectures tested
- Validation results
- Privacy and compatibility impact
- Screenshots only when the interface changes, with all identifiers removed

## Security issues

Do not report vulnerabilities through a normal public issue. Follow [SECURITY.md](SECURITY.md).
