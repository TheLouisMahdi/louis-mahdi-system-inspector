# Changelog

All notable changes to LouisMahdi System Inspector are documented in this file.

The format follows the principles of Keep a Changelog, and the project uses semantic versioning for public releases.

## [Unreleased]

### Added

- Windows GitHub Actions validation and portable build verification
- Privacy-aware issue forms and pull request checklist
- Contribution and release guidance
- Reproducible source-manifest generator

### Changed

- Completed and corrected the sample TXT and JSON reports
- Expanded privacy and security documentation
- Normalized repository line-ending and editor conventions

## [2.2.0] - 2026-07-30

### Added

- Managed-resource PowerShell application payload
- SHA-256 verification for the embedded application source
- AnyCPU launcher compilation
- Native Windows PowerShell discovery
- Compiled launcher self-test
- EXE SHA-256 output
- x86, x64, ARM64, Desktop Experience, Server Core, RDP, and virtual-machine compatibility documentation

### Changed

- Replaced the Base64 in-process PowerShell host with an out-of-process Windows PowerShell launcher

### Removed

- Runtime Base64 decoding of the application payload
- In-process `System.Management.Automation` assembly dependency

### Compatibility

- Preserved collectors, interface behavior, report schema 2.1, privacy defaults, command-line behavior, and TXT, JSON, HTML, and ZIP output

[Unreleased]: https://github.com/TheLouisMahdi/louis-mahdi-system-inspector/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/TheLouisMahdi/louis-mahdi-system-inspector/releases/tag/v2.2.0
