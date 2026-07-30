# LouisMahdi System Inspector 2.2.0

Version 2.2.0 replaces the compiled startup host while preserving the inventory collectors, privacy defaults, report schema, report formats, GitHub-inspired interface, and command-line behavior.

## Fixed

- Removed runtime Base64 decoding of the complete PowerShell application.
- Removed the in-process `System.Management.Automation` assembly dependency from the launcher.
- Embedded the application and icon as named managed resources.
- Added SHA-256 verification of the embedded PowerShell source before execution.
- Added native Windows PowerShell discovery across 32-bit, 64-bit, and ARM64-capable Windows environments.
- Added `Sysnative`, `System32`, `SysWOW64`, and `PATH` fallback order.
- Added a compiled launcher self-test.
- Added a runtime diagnostic file at `%TEMP%\LouisMahdi_SystemInspector_LastError.txt` when startup fails.
- Added a launcher-provided icon path so the PowerShell GUI keeps the LouisMahdi application icon.

## Distribution

The builder creates an AnyCPU EXE. The distributed EXE contains no runtime Base64 application payload and performs no internet download.

Developed by LouisMahdi  
https://github.com/TheLouisMahdi
