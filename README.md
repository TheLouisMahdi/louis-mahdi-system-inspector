# LouisMahdi System Inspector

A professional, read-only, offline Windows hardware and operating-system inventory application with privacy-aware TXT, JSON, and HTML reports.

**Version:** 2.2.0  
**Developed by:** LouisMahdi  
**Repository:** [github.com/TheLouisMahdi/louis-mahdi-system-inspector](https://github.com/TheLouisMahdi/louis-mahdi-system-inspector)

## Highlights

- GitHub-inspired black and green desktop interface
- Privacy mode enabled by default
- Standard and Extended report modes
- TXT, structured JSON, and self-contained HTML output
- ZIP export ready to send
- Read-only data collection
- No automatic internet access, telemetry, upload, dependency download, benchmark, or system modification
- Capability detection, source attribution, validation, fallbacks, and graceful degradation
- Single-file AnyCPU EXE distribution
- Managed-resource application payload with SHA-256 verification
- No runtime Base64 decoding
- No in-process `System.Management.Automation` assembly binding

## Supported environments

### Primary target

- Windows 10 and Windows 11
- Windows Server 2016 or later
- Windows PowerShell 5.1
- Standard-user and administrator execution
- x86 and x64 Windows through the AnyCPU launcher
- Windows 11 ARM64 with .NET Framework 4.8.1
- Laptops, desktops, workstations, virtual machines, hybrid-GPU systems, and multi-monitor systems

### Server notes

- GUI mode requires a desktop-capable Windows installation.
- On Server Core, use `--nogui`.
- Display, battery, Secure Boot, TPM, storage-health, and vendor-specific values may remain unavailable when the operating system, firmware, driver, session type, or permissions do not expose them.

### Not a target

- Windows 7
- Windows 8 or 8.1
- Windows RT
- Nano Server GUI execution
- Windows installations without Windows PowerShell 5.1

No single executable can guarantee that every optional hardware provider exists on every Windows device. Unsupported providers are reported explicitly instead of terminating the report.

## Run from source

Double-click:

```text
Run_Source.bat
```

Or run directly:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File .\src\LouisMahdi.SystemInspector.ps1
```

## Build the single-file EXE

Double-click:

```text
Build_LouisMahdi_System_Inspector_ONE_FILE.bat
```

The builder:

1. Loads the project source directly when the repository files are present.
2. Falls back to its embedded offline files when used as a standalone builder.
3. Validates the PowerShell source and launcher contracts.
4. Runs offline mock-provider tests.
5. Embeds the PowerShell application as a managed assembly resource.
6. Stores the expected source SHA-256 inside the launcher.
7. Compiles an AnyCPU Windows executable with the built-in .NET Framework compiler.
8. Runs a launcher self-test against the compiled EXE.
9. Creates an EXE SHA-256 file.

Output:

```text
LouisMahdi_System_Inspector.exe
LouisMahdi_System_Inspector.exe.sha256.txt
```

Only the EXE is required for normal distribution.

## Why version 2.2.0 uses a new launcher

Older builds converted the complete application to a large Base64 string inside the EXE. A transferred build could fail before startup with an invalid Base64 error. Version 2.2.0 removes that runtime mechanism completely.

The EXE now:

- Reads the PowerShell source from a named managed resource.
- Verifies the source with SHA-256 before execution.
- Locates the native Windows PowerShell installation.
- Extracts the verified source and icon to a unique temporary directory.
- Starts Windows PowerShell 5.1 in STA mode without a console window.
- Waits for the application to close and removes the temporary files.

## Command-line mode

Standard private report:

```powershell
.\LouisMahdi_System_Inspector.exe --nogui --html
```

Extended report with privacy retained:

```powershell
.\LouisMahdi_System_Inspector.exe --nogui --extended --html
```

Extended unredacted report:

```powershell
.\LouisMahdi_System_Inspector.exe --nogui --extended --unredacted --html
```

Custom output folder:

```powershell
.\LouisMahdi_System_Inspector.exe --nogui --html --output="D:\Reports"
```

Retain developer diagnostics:

```powershell
.\LouisMahdi_System_Inspector.exe --nogui --html --retain-diagnostics
```

Launcher-only self-test:

```powershell
.\LouisMahdi_System_Inspector.exe --launcher-self-test
```

## Output files

- `System_Report.txt`
- `System_Report.json`
- `System_Report.html`
- Optional `Developer_Diagnostics.jsonl`
- A ZIP package containing the selected report files

## Privacy

Privacy mode is enabled by default. Standard reports redact or omit usernames, UUIDs, serial numbers, MAC addresses, IP addresses, Wi-Fi SSIDs, domain details, and other identifiers. Unredacted output requires Extended mode and an explicit privacy opt-out.

The application performs no automatic network request. The GitHub profile opens only when the user clicks the GitHub link in the interface or report.

## Tests

Double-click:

```text
Run_Tests.bat
```

The test chain validates:

- PowerShell syntax
- GUI startup contracts
- PowerShell 5.1 collection boundaries
- Launcher managed-resource loading
- Source-integrity verification
- Absence of runtime Base64 decoding
- Absence of in-process PowerShell assembly binding
- AnyCPU build contract
- Mocked provider behavior

## Repository structure

```text
assets/     Application icon and logo
docs/       Architecture, compatibility, source priority, and limitations
samples/    Example TXT and JSON reports
src/        Production PowerShell application
tests/      Parser checks, launcher checks, mock tests, and test matrix
```

## Security note

The generated EXE is unsigned. Windows SmartScreen may show an unknown-publisher warning until the application is signed with a trusted code-signing certificate and gains reputation.

## License

This project is released under the MIT License. See [LICENSE](LICENSE).

## Project credit

Developed by LouisMahdi  
[https://github.com/TheLouisMahdi/louis-mahdi-system-inspector](https://github.com/TheLouisMahdi/louis-mahdi-system-inspector)
