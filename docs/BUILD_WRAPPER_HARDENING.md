# Build Wrapper Hardening

Version 2.2.0 preserves the inventory, reporting, privacy, interface, and command-line behavior of version 2.1.10.

The build wrapper applies the following reliability rules:

- Batch files are encoded without a UTF-8 byte-order mark.
- Repository files are used directly when present.
- Embedded offline files are used only when the builder is separated from the repository.
- The PowerShell source is parsed before compilation.
- Mock tests must pass before compilation.
- The launcher source must use managed resources and SHA-256 verification.
- The launcher source must not use runtime Base64 decoding.
- The launcher source must not bind to `System.Management.Automation`.
- The generated EXE must pass `--launcher-self-test` before distribution.
- A failed validation, compilation, or self-test deletes or withholds the EXE.

No collector, report field, privacy rule, output format, interface control, or report schema was removed.
