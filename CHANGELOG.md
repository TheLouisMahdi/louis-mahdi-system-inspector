# Changelog

## 2.2.0

- Replaced the Base64 in-process PowerShell host with a managed-resource launcher.
- Added SHA-256 verification for the embedded application source.
- Removed the runtime `System.Management.Automation` assembly dependency.
- Added AnyCPU compilation and native Windows PowerShell discovery.
- Added the launcher self-test and EXE SHA-256 output.
- Added x86, x64, ARM64, Desktop Experience, Server Core, RDP, and virtual-machine compatibility documentation.
- Preserved collectors, UI, report schema 2.1, privacy behavior, and output formats.
