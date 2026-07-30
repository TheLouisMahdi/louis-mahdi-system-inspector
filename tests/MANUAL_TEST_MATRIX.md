# Manual test matrix

Record OS build, privilege level, report mode, privacy mode, section status, warnings, and output validation for each case.

## OEM / architecture

- Lenovo laptop
- ASUS laptop
- HP laptop
- Dell desktop
- Custom-built desktop
- x64 AMD processor
- x64 Intel processor
- ARM64 Windows device
- Supported Windows Server edition
- Localized non-English Windows installation
- Standard-user execution
- Administrator execution

## Graphics / displays

- Integrated graphics only
- NVIDIA dedicated GPU
- AMD dedicated GPU
- Intel Arc GPU
- Hybrid AMD + NVIDIA
- Multiple dedicated GPUs
- One monitor
- Multiple monitors
- Remote Desktop session
- Virtual machine graphics adapter

## Memory

- 8 GB + 16 GB
- Matching modules
- Duplicate DeviceLocator values
- Missing manufacturer
- Soldered memory where reported

## Storage

- NVMe SSD
- SATA SSD
- SATA HDD
- USB storage
- RAID controller
- Storage Spaces
- Virtual disk
- Missing Storage module
- Driver with no reliability counters

## Battery / security

- No battery
- One battery
- Multiple batteries
- UPS-reported battery
- No TPM
- TPM disabled in firmware
- TPM present but not ready
- Missing TrustedPlatformModule module
- Legacy BIOS
- UEFI + Secure Boot disabled
- UEFI + Secure Boot enabled

## Network

- Disconnected Ethernet
- Connected Gigabit Ethernet
- Wi-Fi
- VPN
- Hyper-V
- VMware / VirtualBox
- PdaNet
- malformed/overflowed WMI speed fixture

## Failure injection

- WMI/CIM provider timeout
- Permission denied
- Null SMBIOS values
- OEM placeholder strings
- Malformed dates
- Conflicting RAM totals
- Conflicting disk mappings
- Missing `nvidia-smi`

## Launcher and distribution

- EXE built on Windows 10 x64 and executed on a different Windows 10 x64 computer
- EXE built on Windows 11 x64 and executed on Windows 10 x64
- EXE executed on Windows 11 ARM64 with .NET Framework 4.8.1
- EXE executed from a path containing spaces and non-English characters
- EXE copied through USB storage
- EXE downloaded from a GitHub release ZIP
- `--launcher-self-test` after transfer
- Source resource SHA-256 mismatch fixture
- Missing Windows PowerShell fixture
- 32-bit process on 64-bit Windows using the Sysnative fallback
- Server Core `--nogui` execution
- SmartScreen unknown-publisher warning documentation
