# Defect analysis of the former implementation

The former version was useful as a quick personal inventory script but was not safe to generalize across different PCs. The following defects were identified and corrected in version 2.0.

## Parsing and packaging

- A `try/catch` expression was placed inside a hashtable value in a form that failed under Windows PowerShell 5.1 after PS2EXE conversion.
- The previous build path depended on installing PS2EXE from the internet.
- The generated EXE was not protected by a mandatory parser pass or mocked smoke-test stage.

Version 2.0 uses a native PowerShell parser check before compilation, offline mock tests, and a small built-in .NET host that embeds the validated source.

## Data correctness

- `Win32_Processor.MaxClockSpeed` was effectively treated as an advertised boost clock. It is now labelled **SMBIOS-Reported Maximum Clock** and never represented as a live or advertised turbo value.
- Static WMI clock data could be mistaken for real-time per-core frequency. Live sampling is now explicitly unavailable unless a separately identified sampling method exists.
- Duplicate RAM `DeviceLocator` values could imply one physical slot. Modules are now indexed independently and `DeviceLocator`, `BankLabel`, `Tag`, serial number, and report index remain separate.
- Channel mode could be guessed from RAM capacities. Version 2.0 makes no channel-mode inference.
- Missing TPM values could render as blank. Every TPM property now has an explicit state and source.
- Secure Boot, firmware mode, and permission failure were merged into a vague sentence. They are now independent fields with independent query states.
- GPU resolution and refresh rate could appear under every GPU and produce malformed `x` or `Hz` output. Display topology is now a separate section.
- WMI `AdapterRAM` was trusted too strongly. It is now labelled as a WMI value, validated for overflow/truncation, and placed below optional vendor/native values in priority.
- Integrated graphics preallocated memory could be presented as total usable VRAM. Version 2.0 does not make that conclusion.
- Storage `Status = OK` could be interpreted as complete disk health. Device status, Storage HealthStatus, OperationalStatus, SMART prediction, and reliability counters are reported separately.
- Battery health could be confused with charge percentage or WMI `Status = OK`. Health is calculated only from compatible design/full-charge capacities.
- Physical and virtual network adapters could be mixed. They now have separate sections, with explicit recognition of PdaNet, VPN, Hyper-V, VMware, VirtualBox, loopback, tunneling, WSL, Docker, and similar software adapters.
- Link speed could be converted twice or overflow, producing impossible values. `Get-NetAdapter.LinkSpeed` is preferred, WMI speed is treated as raw bits per second, and all values are range-validated.
- Decimal GB and binary GiB were not consistently distinguished. Exact bytes are retained, with separate SI and IEC displays.
- Missing values could collapse into blank strings or zero. Version 2.0 uses explicit status values and never turns null into zero.

## Architecture and maintainability

The former implementation directly formatted provider output while collecting it. Version 2.0 separates:

1. Provider query and fallback handling
2. Normalization and inference
3. Validation and conflict detection
4. Privacy transformation
5. Internal data model
6. TXT, JSON, and HTML presentation

The programming language and WinForms user-interface approach were retained because they remain appropriate for an offline Windows-native utility. The data-collection, validation, privacy, packaging, and reporting layers were rebuilt where technically necessary.
