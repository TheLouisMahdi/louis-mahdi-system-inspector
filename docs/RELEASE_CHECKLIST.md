# Release Checklist

Use this checklist for every public release.

## Version consistency

- [ ] Update `$script:AppVersion` in `src/LouisMahdi.SystemInspector.ps1`
- [ ] Update assembly versions in `docs/LouisMahdiHost.cs`
- [ ] Update the builder title and displayed version
- [ ] Update `README.md`, `CHANGELOG.md`, `RELEASE_NOTES.md`, `CODE_QUALITY.txt`, and sample reports
- [ ] Keep the report schema version unchanged unless the JSON contract changes

## Validation

- [ ] Confirm the Windows validation workflow is green
- [ ] Run `Run_Tests.bat` on a local Windows system
- [ ] Build with `Build_LouisMahdi_System_Inspector_ONE_FILE.bat`
- [ ] Run `LouisMahdi_System_Inspector.exe --launcher-self-test`
- [ ] Generate a Standard private report
- [ ] Generate an Extended private report
- [ ] Validate TXT, JSON, HTML, and ZIP output
- [ ] Confirm the JSON report parses successfully
- [ ] Confirm no personal identifiers appear in sample files

## Compatibility sampling

- [ ] Windows 10 x64
- [ ] Windows 11 x64
- [ ] Standard-user execution
- [ ] Administrator execution
- [ ] Laptop or battery-capable device when available
- [ ] Multi-GPU or multi-monitor device when available
- [ ] Windows Server or command-line-only mode when available
- [ ] ARM64 only when a real ARM64 test system is available

Record untested targets as targets or expected compatibility rather than verified compatibility.

## Release assets

Upload exactly:

- `LouisMahdi_System_Inspector.exe`
- `LouisMahdi_System_Inspector.exe.sha256.txt`

Verify the checksum before upload:

```powershell
$actual = (Get-FileHash .\LouisMahdi_System_Inspector.exe -Algorithm SHA256).Hash.ToLowerInvariant()
$expected = ((Get-Content .\LouisMahdi_System_Inspector.exe.sha256.txt -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
if ($actual -ne $expected) { throw 'Checksum mismatch.' }
```

## GitHub release

- [ ] Create an annotated or lightweight tag in the form `vMAJOR.MINOR.PATCH`
- [ ] Target the reviewed `main` commit
- [ ] Use the title `LouisMahdi System Inspector vMAJOR.MINOR.PATCH`
- [ ] Mark stable releases as the latest release
- [ ] Do not mark a stable release as a pre-release
- [ ] Include highlights, privacy behavior, compatibility notes, security notice, and the SHA-256 value
- [ ] Confirm the README **Download latest release** link opens the published release
- [ ] Download the EXE back from GitHub and verify its SHA-256 again

## After publication

- [ ] Test the downloaded release on a clean Windows user account or virtual machine
- [ ] Confirm Windows SmartScreen behavior is accurately documented
- [ ] Confirm the release contains no unintended source archives or private reports beyond GitHub's automatic source archives
- [ ] Confirm Issues, Security, License, Privacy, and Contributing links remain valid
