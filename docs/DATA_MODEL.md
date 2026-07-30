# Internal data model

All report formats are generated from the same in-memory model. TXT is never parsed to create JSON.

## Field object

Every collected property contains:

| Property | Meaning |
|---|---|
| `DisplayName` | Human-facing label |
| `RawValue` | Original provider value, or `[REDACTED]` in privacy mode |
| `NormalizedValue` | Validated/normalized value without presentation units |
| `Unit` | Unit stored separately |
| `Source` | Provider/API/tool used |
| `SourceProperty` | Original property or calculation |
| `CollectionStatus` | Explicit collection state |
| `Confidence` | High, Medium, Low, or Unknown |
| `ErrorMessage` | Sanitized reason for non-availability/failure |
| `IsSensitive` | Whether the value is privacy-sensitive |
| `IsInferred` | Whether the value is inferred rather than directly reported |
| `IsRedacted` | Whether privacy transformation was applied |
| `DisplayValue` | Nonblank presentation value |

## Collection states

- `Available`
- `NotAvailable`
- `NotSupported`
- `PermissionDenied`
- `QueryFailed`
- `InvalidValue`
- `NotApplicable`
- `Disconnected`
- `VendorToolUnavailable`
- `Redacted`

## Hierarchy

```text
Report
├── SchemaVersion
├── Application
├── Metadata
├── Privacy
├── SourcePriority
├── Sections[]
│   ├── Name
│   ├── Status
│   ├── DurationMs
│   ├── Items[]
│   │   ├── Title
│   │   ├── Index
│   │   ├── Fields[]
│   │   └── Warnings[]
│   ├── Warnings[]
│   └── Errors[]
├── Warnings[]
└── Errors[]
```

## Error object

Each isolated provider failure records section, source, exception type, sanitized message, HRESULT when available, administrator-remediation indication, duration, and fallback result.

## Privacy model

Standard mode enforces privacy mode. Extended mode can remain redacted or be explicitly unredacted. Sensitive raw values are not retained in the JSON model when privacy mode is active, preventing leakage into TXT, JSON, HTML, or diagnostics.
