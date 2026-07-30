# Compatibility

## Launcher architecture

The compiled launcher uses `.NET Framework AnyCPU`. It does not reference `System.Management.Automation` and does not execute a Base64 application payload. It locates Windows PowerShell at runtime and starts the operating-system-provided engine.

## Operating systems

| Environment | GUI | CLI | Status |
|---|---:|---:|---|
| Windows 10 x86 | Yes | Yes | Supported where Windows PowerShell 5.1 and .NET Framework 4.x are present |
| Windows 10 x64 | Yes | Yes | Supported |
| Windows 11 x64 | Yes | Yes | Supported |
| Windows 11 ARM64 | Yes | Yes | Supported with .NET Framework 4.8.1 |
| Windows Server 2016+ Desktop Experience | Yes | Yes | Supported |
| Windows Server Core 2016+ | No | Yes | Use `--nogui`; GUI-dependent fields may be unavailable |
| Remote Desktop session | Yes | Yes | Supported; active display data may describe the remote session |
| Virtual machine | Yes | Yes | Supported; firmware and hardware data depend on the hypervisor |

## Capability-dependent data

The application continues when an optional provider is absent. Common capability-dependent areas include:

- Secure Boot
- TPM
- Battery capacity and cycle count
- Monitor EDID
- GPU VRAM and temperature
- Storage reliability counters
- SMART prediction
- Vendor-specific tools
- Network driver telemetry

## Architecture behavior

The launcher selects Windows PowerShell in this order:

1. Native `Sysnative` Windows PowerShell when a 32-bit process runs on a 64-bit operating system
2. `System32` Windows PowerShell
3. `SysWOW64` Windows PowerShell
4. `powershell.exe` from `PATH`

The report records the actual PowerShell process and operating-system architecture. Provider availability is determined at runtime rather than assumed from architecture.
