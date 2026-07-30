# Administrator requirements and unavoidable limitations

## Features that may require administrator privileges

- Reading Secure Boot state through `Confirm-SecureBootUEFI` on some systems
- Reading complete TPM state or the TPM WMI namespace on hardened systems
- Reading some storage reliability counters and SMART-related provider classes
- Reading BitLocker state in Extended mode
- Accessing some PnP/driver properties under enterprise policy
- Querying certain battery, firmware, or device-provider namespaces

The application does not request elevation automatically. It reports `PermissionDenied` and continues with other sections.

## Values that may remain unavailable

Even with administrator rights, firmware and drivers may not expose:

- Advertised CPU boost/turbo clock or accurate real-time per-core frequency
- Memory channel/rank topology
- Accurate dedicated VRAM through generic WMI, especially for integrated/hybrid graphics
- A reliable GPU-to-monitor physical path on every driver stack
- Monitor HDR, connection type, physical dimensions, serial number, or complete EDID
- Secure Boot hardware capability when firmware/provider behavior is ambiguous
- TPM version/state when the device is disabled in firmware or its namespace is absent
- SMART/reliability counters behind USB bridges, RAID controllers, Storage Spaces, virtual disks, or vendor drivers
- Battery cycle count, voltage, design capacity, full-charge capacity, or chemistry
- Wi-Fi PHY standard and negotiated transmit/receive rates from generic providers
- Maximum theoretical network-adapter capability
- Complete hardware data in virtual machines, Remote Desktop sessions, containers, or vendor-restricted systems

Unavailable values remain explicit and are never converted to blank text or zero.

## Distribution limitations

The generated EXE embeds the application and needs no adjacent files. It relies on Windows PowerShell 5.1 and .NET Framework 4.x. Windows PowerShell 5.1 is present by default on Windows 10, Windows 11, and Windows Server 2016 or later. Windows 11 ARM64 requires .NET Framework 4.8.1 for native ARM64 managed execution. Server Core should use command-line mode. It is unsigned unless the developer signs it; SmartScreen may therefore display a reputation warning.
