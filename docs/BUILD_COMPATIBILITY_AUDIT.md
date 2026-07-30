# Build Compatibility Audit

Version 2.2.0 preserves the reporting behavior of version 2.1.10 and replaces only the compiled launcher and build pipeline.

## PowerShell source

- Requires Windows PowerShell 5.1.
- Starts the main form at full opacity.
- Uses `ShowInTaskbar = $true` and `WindowState = 'Normal'`.
- Does not depend on a fade timer for visibility.
- Accepts a launcher-provided icon path.
- Preserves explicit `ToArray()` materialization at generic-list aggregation boundaries.

## Compiled launcher

- Uses the built-in .NET Framework C# compiler.
- Targets AnyCPU.
- Does not reference `System.Management.Automation`.
- Does not decode the application from Base64 at runtime.
- Embeds the PowerShell application as a named managed resource.
- Embeds the application icon as a named managed resource.
- Verifies the embedded PowerShell source using SHA-256.
- Locates Windows PowerShell through `Sysnative`, `System32`, `SysWOW64`, and `PATH` fallbacks.
- Starts Windows PowerShell with `-STA`, `-NoProfile`, and a process-only execution-policy bypass.
- Suppresses the PowerShell console window.
- Waits for application termination and removes temporary files.

## Build validation

- PowerShell parser validation
- Source startup-contract validation
- Launcher managed-resource validation
- Runtime Base64 prohibition
- In-process PowerShell assembly prohibition
- Offline mock-provider tests
- Compiled launcher self-test
- EXE SHA-256 generation

## Distribution

The generated EXE is a single-file distribution artifact. It temporarily extracts its verified source and icon only for the lifetime of the application.
