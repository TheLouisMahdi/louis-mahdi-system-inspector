## Summary

Describe the problem and the focused change.

## Validation

- [ ] `Validate-Source.ps1` passed
- [ ] `Validate-Launcher.ps1` passed
- [ ] `Run-MockTests.ps1` passed
- [ ] The portable EXE built successfully
- [ ] The launcher self-test passed
- [ ] The generated EXE checksum matched

## Compatibility

List the Windows versions and architectures tested.

## Project contracts

- [ ] Read-only operation is preserved
- [ ] Privacy mode remains enabled by default
- [ ] No telemetry or automatic upload was added
- [ ] No automatic dependency download or update check was added
- [ ] Windows PowerShell 5.1 compatibility is preserved
- [ ] Inferred values remain distinguishable from reported values
- [ ] Unavailable and unsupported states remain explicit

## Documentation

- [ ] Tests were added or updated when behavior changed
- [ ] Sample reports remain valid and contain no real identifiers
- [ ] Changelog and release notes were updated when required
- [ ] Screenshots contain no personal or device identifiers
