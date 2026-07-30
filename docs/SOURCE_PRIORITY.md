# Source-priority and conflict policy

Lower-priority sources never silently overwrite higher-priority values. Conflicting raw values remain available in the structured report and generate warnings where meaningful.

| Field group | Priority, highest first |
|---|---|
| Computer identity | `Win32_ComputerSystem` → `Win32_ComputerSystemProduct` → `Win32_SystemEnclosure` → `Win32_BaseBoard` |
| Windows product/build | CurrentVersion registry → `Win32_OperatingSystem` → `Get-ComputerInfo` consistency fallback |
| Processor | `Win32_Processor`; optional explicitly-labelled performance sampling only |
| Installed memory | Sum of valid `Win32_PhysicalMemory.Capacity`; OS-visible memory remains a separate value |
| Memory identity | Direct SMBIOS values → optional part-number inference shown separately |
| GPU identity/driver | `Win32_VideoController` → `Win32_PnPSignedDriver`/PnP correlation |
| GPU dedicated VRAM | Installed vendor tool → native display source when available → validated WMI `AdapterRAM` → unavailable |
| Active display mode | Windows display-configuration API → `System.Windows.Forms.Screen` fallback; EDID/WMI for identity only |
| Firmware mode | Native `GetFirmwareType` API → `PEFirmwareType` registry → unavailable |
| Secure Boot | `Confirm-SecureBootUEFI`, interpreted together with independently collected firmware mode |
| TPM | `Get-Tpm` → `Win32_Tpm` in `root\CIMV2\Security\MicrosoftTpm` |
| Physical disk identity | Stable identifiers across `Get-Disk`/`Get-PhysicalDisk` → `Win32_DiskDrive` → model/size fallback |
| Storage media/bus | Storage module `MediaType`/`BusType` → WMI interface data → explicitly-labelled model inference |
| Storage health | Reliability counters → Storage `HealthStatus` → `OperationalStatus` → SMART prediction → WMI device status |
| Volumes | `Get-Volume` + `Get-Partition` mapping → `Win32_LogicalDisk` fallback |
| Battery capacity | `powercfg /batteryreport /xml` → WMI battery capacity classes → `Win32_Battery` status/charge support |
| Network status/speed | `Get-NetAdapter` → raw `Win32_NetworkAdapter.Speed` fallback |
| Network driver | `Win32_PnPSignedDriver` correlated by PnP device ID |

## Conflict handling

1. Preserve each raw source value in its own field or diagnostic record.
2. Select the displayed value from the highest valid source.
3. Validate units, range, provider semantics, and correlation confidence.
4. Add a warning when valid sources disagree materially.
5. Never replace a missing direct value with inference without displaying `IsInferred`, inference source, and confidence.
